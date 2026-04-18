import java.util.Properties

plugins {
    id("com.android.library")
    id("kotlin-android")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val flutterSdkPath: String = localProperties.getProperty("flutter.sdk")
    ?: error("flutter.sdk not set in local.properties")

android {
    namespace = "com.example.triggerroyale"
    compileSdk = 36

    defaultConfig {
        minSdk = 34
    }

    sourceSets {
        getByName("main") {
            java.srcDir("../../../TriggerRoyale/app/src/main/java")
            assets.srcDir("../../../TriggerRoyale/app/src/main/assets")
            manifest.srcFile("src/main/AndroidManifest.xml")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    aaptOptions {
        noCompress += "tflite"
    }
}

dependencies {
    compileOnly(files("$flutterSdkPath/bin/cache/artifacts/engine/android-arm64/flutter.jar"))
    implementation("androidx.camera:camera-core:1.3.1")
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("androidx.camera:camera-view:1.3.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("com.google.mediapipe:tasks-vision:0.10.14")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    exclude("**/MainActivity.kt")
}
