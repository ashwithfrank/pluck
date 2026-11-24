plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.aos"
        // youtubedl-android requires API 24+
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    // One APK per CPU: the yt-dlp + python + ffmpeg bundle is big, so split it.
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }

    packaging {
        jniLibs {
            // Required: the bundled binaries are executed from the native lib dir.
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // Replace with your own signing config before publishing.
            signingConfig = signingConfigs.getByName("debug")
            // Keep shrinking off: the library loads classes reflectively.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    val ytdl = "0.16.0"
    implementation("io.github.junkfood02.youtubedl-android:library:$ytdl")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:$ytdl")
    implementation("io.github.junkfood02.youtubedl-android:aria2c:$ytdl")
    implementation("androidx.core:core-ktx:1.13.1")
}
