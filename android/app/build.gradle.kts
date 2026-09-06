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
        
        // Add 16KB page size support
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }
    
    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        create("release") {
            if (!hasReleaseSigning) {
                throw GradleException(
                    "Release signing is not configured. Add android/key.properties " +
                        "or set ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
                        "ANDROID_KEY_ALIAS, and ANDROID_KEY_PASSWORD."
                )
            }
            storeFile = file(releaseStoreFile!!)
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
    
    // Add 16KB page size support
    packagingOptions {
        jniLibs {
            useLegacyPackaging = false
        }
    }
    
    // Fix AAR metadata warnings (Flutter plugins don't always include required metadata)
    lint {
        checkReleaseBuilds = false
        abortOnError = false
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
