import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // Native Android symbol upload (R8/mapping + NDK). Dart obfuscation symbols
    // are retained under symbols/<version>/ and uploaded via scripts/upload_crashlytics_symbols.sh.
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseStoreFile =
    keystoreProperties.getProperty("storeFile") ?: System.getenv("ANDROID_KEYSTORE_PATH")
val releaseStorePassword =
    keystoreProperties.getProperty("storePassword") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias =
    keystoreProperties.getProperty("keyAlias") ?: System.getenv("ANDROID_KEY_ALIAS")
val releaseKeyPassword =
    keystoreProperties.getProperty("keyPassword") ?: System.getenv("ANDROID_KEY_PASSWORD")

val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.streamerstip.streamersTipApp"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.streamerstip.streamersTipApp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ABI selection is owned by the Flutter Gradle plugin. An ndk.abiFilters
        // list here makes AGP emit ABI-named APKs (app-arm64-v8a-debug.apk).
        // `flutter run` only looks for app-debug.apk, so the build looks
        // successful and then fails with "Gradle build failed to produce an
        // .apk file". 16 KB page alignment is packaging.jniLibs below, not an
        // ABI filter.
    }
    
    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // 16 KB page alignment: uncompressed JNI libs, aligned by the Flutter NDK.
    packagingOptions {
        jniLibs {
            useLegacyPackaging = false
        }
    }
    
    // Lint configuration for production quality
    lint {
        checkReleaseBuilds = true
        abortOnError = true
        // Disable specific checks that are Flutter plugin issues, not app issues
        disable.add("InvalidPackage")
        disable.add("MissingClass")
    }
}

// Disable AAR metadata checks (workaround for Flutter plugins)
// These checks fail because Flutter plugins don't always include required AAR metadata
afterEvaluate {
    tasks.matching { it.name.contains("check") && it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-ui:1.5.1")
}

flutter {
    source = "../.."
}

// Suppress Java 8 obsolete warnings temporarily
tasks.withType<JavaCompile> {
    options.compilerArgs.addAll(listOf("-Xlint:-options"))
}

// `flutter run` looks only for <repo>/build/app/outputs/flutter-apk/app-<mode>.apk.
// ABI filters and a relocated Gradle build dir can leave the APK under an
// ABI-specific name or under android/app/build. Copy the arm64 APK (Pixel 6
// and Apple Silicon emulators) to the filename and directory Flutter expects.
tasks.matching {
    it.name == "assembleDebug" || it.name == "assembleProfile" || it.name == "assembleRelease"
}.configureEach {
    doLast {
        val mode = name.removePrefix("assemble").replaceFirstChar { it.lowercase() }
        val relocated = layout.buildDirectory.get().asFile
        val repoAppBuild = rootProject.projectDir.resolve("../build/app")
        val defaultAppBuild = project.projectDir.resolve("build")
        val searchDirs = listOf(
            relocated.resolve("outputs/flutter-apk"),
            relocated.resolve("outputs/apk/$mode"),
            repoAppBuild.resolve("outputs/flutter-apk"),
            repoAppBuild.resolve("outputs/apk/$mode"),
            defaultAppBuild.resolve("outputs/flutter-apk"),
            defaultAppBuild.resolve("outputs/apk/$mode"),
        )
        fun apkFiles(dir: File): List<File> =
            if (dir.isDirectory) {
                dir.listFiles()?.filter { it.isFile && it.name.endsWith(".apk") }.orEmpty()
            } else {
                emptyList()
            }
        val pool = searchDirs.flatMap(::apkFiles).distinctBy { it.canonicalPath }
        val chosen = pool.firstOrNull { it.name == "app-$mode.apk" }
            ?: pool.firstOrNull { it.name.contains("arm64-v8a") && it.name.endsWith("-$mode.apk") }
            ?: pool.firstOrNull { it.name.contains("x86_64") && it.name.endsWith("-$mode.apk") }
            ?: pool.firstOrNull { it.name.endsWith("-$mode.apk") }
            ?: return@doLast
        listOf(
            relocated.resolve("outputs/flutter-apk/app-$mode.apk"),
            repoAppBuild.resolve("outputs/flutter-apk/app-$mode.apk"),
        ).distinctBy { it.canonicalPath }.forEach { expected ->
            if (!expected.isFile) {
                expected.parentFile.mkdirs()
                chosen.copyTo(expected, overwrite = true)
            }
        }
    }
}
