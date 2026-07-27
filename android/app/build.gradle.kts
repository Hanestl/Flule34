import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val releaseSigningConfigured = keystorePropertiesFile.exists()

if (releaseSigningConfigured) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach { name ->
        require(!keystoreProperties.getProperty(name).isNullOrBlank()) {
            "android/key.properties 缺少必填项：$name"
        }
    }
}

android {
    namespace = "com.hanestl.flule34"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hanestl.flule34"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    lint {
        // Pub 插件可能位于不同盘符；只审计本应用模块，第三方依赖由其上游维护。
        checkDependencies = false
        // Flutter 会在 Windows 上把 local.properties 重写为反斜杠路径，
        // AGP 9 的 PropertyEscape 检查会对此产生误报。
        disable += "PropertyEscape"
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

dependencies {
    // background_downloader 9.5.6 的 URI 下载实现直接使用 DocumentFile，
    // 但插件自身未声明该运行时依赖，必须由应用显式补齐。
    implementation("androidx.documentfile:documentfile:1.1.0")
}

tasks.matching { task ->
    task.name == "assembleRelease" || task.name == "bundleRelease"
}.configureEach {
    doFirst {
        if (!releaseSigningConfigured) {
            throw GradleException(
                "Release 构建需要 android/key.properties；请参考 android/key.properties.example 和 docs/release.md。",
            )
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
