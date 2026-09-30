plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.servomap.android"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.servomap.android"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        // Override with -PapiBase=http://10.0.2.2:8787/api/v1 to hit a local `wrangler dev` from the emulator.
        val apiBase = (project.findProperty("apiBase") as String?) ?: "https://api.servo-map.com/api/v1"
        buildConfigField("String", "API_BASE", "\"$apiBase\"")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    testOptions { unitTests.isReturnDefaultValues = true }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.osmdroid:osmdroid-android:6.1.20")

    testImplementation("junit:junit:4.13.2")
}
