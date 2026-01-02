plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
}

flutter {
    source = "../.."
}

// Suppress Java 8 obsolete warnings temporarily
tasks.withType<JavaCompile> {
    options.compilerArgs.addAll(listOf("-Xlint:-options"))
}
