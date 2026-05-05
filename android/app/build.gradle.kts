import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取 key.properties（本地开发用，CI 中通过环境变量传入）
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.mimusic.mimusic_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            // 优先使用环境变量（CI），其次使用 key.properties（本地）
            val storeFilePath = System.getenv("ANDROID_KEYSTORE_PATH")
                ?: keystoreProperties.getProperty("storeFile")
            val storePass = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                ?: keystoreProperties.getProperty("storePassword")
            val keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                ?: keystoreProperties.getProperty("keyAlias")
            val keyPass = System.getenv("ANDROID_KEY_PASSWORD")
                ?: keystoreProperties.getProperty("keyPassword")

            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = storePass
                this.keyAlias = keyAlias
                keyPassword = keyPass
            }
        }
    }

    defaultConfig {
        applicationId = "com.mimusic.mimusic_flutter"
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion // Android Automotive 建议 API 28+，当前使用 Flutter 默认值(21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 使用 release 签名配置；若未配置则回退到 debug（仅本地调试）
            val releaseConfig = signingConfigs.findByName("release")
            signingConfig = if (releaseConfig?.storeFile != null) releaseConfig
                            else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
