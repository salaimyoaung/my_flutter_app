pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // ✅ MUST: Fix AAR metadata error (androidx.* requires 8.9.1+)
    id("com.android.application") version "8.13.2" apply false

    // ✅ Firebase / FlutterFire
    id("com.google.gms.google-services") version "4.4.2" apply false

    // ✅ Flutter warning says Kotlin >= 2.1.0 soon; use a 2.1.x line
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
}

include(":app")