import java.util.Properties

// "OpenIPTV Video": a tiny add-on that shows OpenIPTV's picture on the
// Android Auto screen while parked. Android Auto lists one entry per app and
// OpenIPTV's is its media (audio) entry, so the video screen has to be a
// separate app. It has no player of its own: it hands its screen to
// OpenIPTV (CarVideoService), which draws the stream it is already playing.
// Build: ./gradlew :carvideo:assembleRelease (same signing key as the app —
// the connection is protected by a signature permission).
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.openiptv.carvideo"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.openiptv.app.carvideo"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseKey) {
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
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            isMinifyEnabled = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
