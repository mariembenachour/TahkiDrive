plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") version "4.4.4"
}

android {
    namespace = "com.example.tahki_drive1"
    compileSdk = 36
    ndkVersion = "27.0.12077973"  // ✅ version requise par Firebase et notifications

    defaultConfig {
        applicationId = "com.example.tahki_drive1"
        minSdk = flutter.minSdkVersion                    // minimum requis pour Firebase + notifications
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // ✅ obligatoire pour flutter_local_notifications
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))

    // Dépendances Firebase
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")

    // Core library desugaring pour flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // ✅ version corrigée
}

flutter {
    source = "../.."
}
