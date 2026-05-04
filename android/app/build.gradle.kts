import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Load keystore properties ──────────────────────────────────────────────────
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.smartiot.smart_iot_interface"
    // [FIX] compileSdk 35→36 (required by flutter_blue_plus, shared_preferences, url_launcher)
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // [FIX] Core library desugaring required by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias     = keystoreProperties["keyAlias"] as String
                keyPassword  = keystoreProperties["keyPassword"] as String
                storeFile    = file(keystoreProperties["storeFile"] as String)
                storePassword= keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.smartiot.smart_iot_interface"
        minSdk = flutter.minSdkVersion
        // [FIX] targetSdk 35→36 to match compileSdk
        targetSdk = 36
        versionCode  = flutter.versionCode
        versionName  = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled    = true
            isShrinkResources  = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // [FIX] Core library desugaring — required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
