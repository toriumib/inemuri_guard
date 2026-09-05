import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing secrets live in android/key.properties, which is gitignored.
// See key.properties.example for the shape and how to create the keystore.
//
// ⚠️ NEVER println any value read from here. A previous app of ours leaked its
// storePassword/keyPassword into the build log that way. If a signing key
// leaks, someone else can ship builds that Play accepts as yours.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseSigning = keystoreProperties.getProperty("storeFile") != null &&
    rootProject.file(keystoreProperties.getProperty("storeFile") ?: "").exists()

android {
    namespace = "com.toriumi.inemuri_guard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Play Console 側で先に登録されたパッケージ名に合わせる。
        // namespace はそのまま(コードの Kotlin パッケージとは無関係)。
        applicationId = "com.stop.sleeping"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing when key.properties is absent, so the
            // repo still builds on a machine without the keystore. Such a build
            // is fine for local testing but Play will reject it.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Loud, value-free warning. Shipping a debug-signed AAB to Play fails late and
// confusingly, so say it at build time — without printing any secret.
tasks.register("checkReleaseSigning") {
    doLast {
        if (!hasReleaseSigning) {
            logger.warn(
                "⚠️  android/key.properties が無いため release ビルドは debug 署名です。" +
                    "Play には上げられません。key.properties.example を参照。"
            )
        }
    }
}
tasks.matching { it.name.startsWith("bundleRelease") || it.name.startsWith("assembleRelease") }
    .configureEach { dependsOn("checkReleaseSigning") }

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 背面でも瞼を見続けるための自前実装で使う。
    // Flutter の camera プラグインは CameraX を Activity のライフサイクルに
    // 縛るため、画面を離れるとカメラを手放してしまう。そこで常駐サービス側で
    // Camera2 を直接開き、ML Kit も native で回す。
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("androidx.core:core-ktx:1.13.1")
}
