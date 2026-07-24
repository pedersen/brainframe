plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tech.brainframe.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "tech.brainframe.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Give debug builds a distinct application ID (tech.brainframe.app.debug)
            // so a debug install and a release/profile install coexist on one device
            // as separate apps. Mirrors the ".debug" suffix in linux/CMakeLists.txt
            // and the Apple Debug build configs.
            applicationIdSuffix = ".debug"
            // Debug builds also get a distinct "dev" launcher icon: the assets
            // under src/debug/res/ override main's for the debug build type via
            // Gradle resource merging — no wiring needed here. Regenerate them
            // with `python3 tool/gen_debug_icons.py` (see
            // docs/debug-build-identity.md).
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
