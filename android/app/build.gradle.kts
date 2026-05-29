import org.gradle.api.GradleException
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing — credentials are read from environment variables first
// (CI/CD), then from the local android/key.properties file (developer
// machines).  NEVER hardcode passwords here or commit key.properties.
// See android/key.properties.example for the required file format.
// ---------------------------------------------------------------------------

fun signingValue(envKey: String, propKey: String, propsFile: File): String? {
    System.getenv(envKey)?.takeIf { it.isNotEmpty() }?.let { return it }
    if (propsFile.exists()) {
        val props = Properties().apply { load(FileInputStream(propsFile)) }
        (props[propKey] as? String)?.takeIf { it.isNotEmpty() }?.let { return it }
    }
    return null
}

// Read once before android {} so the values are in scope for both
// signingConfigs and buildTypes.
val keystorePropsFile    = rootProject.file("key.properties")
val signingStorePassword = signingValue("KEYSTORE_PASSWORD", "storePassword", keystorePropsFile)
val signingKeyPassword   = signingValue("KEY_PASSWORD",      "keyPassword",   keystorePropsFile)
val signingKeyAlias      = signingValue("KEY_ALIAS",         "keyAlias",      keystorePropsFile)
val signingStoreFile     = signingValue("KEYSTORE_PATH",     "storeFile",     keystorePropsFile)

android {
    signingConfigs {
        create("release") {
            // All four values must be present — fail with a clear message so
            // the developer knows exactly what to set.
            if (signingStorePassword.isNullOrEmpty() || signingKeyPassword.isNullOrEmpty() ||
                signingKeyAlias.isNullOrEmpty()      || signingStoreFile.isNullOrEmpty()) {
                throw GradleException(
                    "\n\nRelease signing credentials not found.\n" +
                    "Option A — CI/CD: set environment variables:\n" +
                    "  KEYSTORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS, KEYSTORE_PATH\n" +
                    "Option B — Local: create android/key.properties\n" +
                    "  (copy android/key.properties.example and fill in real values)\n" +
                    "Never commit key.properties or hardcode passwords in build scripts.\n"
                )
            }
            keyAlias      = signingKeyAlias!!
            keyPassword   = signingKeyPassword!!
            storeFile     = file(signingStoreFile!!)
            storePassword = signingStorePassword!!
        }
    }
    namespace = "com.atelier.minaret"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.atelier.minaret"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Fail fast if KEYSTORE_PASSWORD is missing — catches CI environments
            // where secrets haven't been injected before a release build runs.
            if (signingStorePassword.isNullOrEmpty()) {
                throw GradleException("KEYSTORE_PASSWORD env var is not set. Cannot build release APK.")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")

            // Additional size optimization settings
            ndk {
                debugSymbolLevel = "NONE"
            }

            manifestPlaceholders["crashlyticsCollectionEnabled"] = "true"
        }

        // Create a minimal build for size optimization
        create("minimal") {
            initWith(getByName("release"))
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Aggressive optimization
            ndk {
                debugSymbolLevel = "NONE"
            }

            manifestPlaceholders["crashlyticsCollectionEnabled"] = "true"
        }
    }

    packagingOptions {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/DEPENDENCIES"
            excludes += "/META-INF/LICENSE"
            excludes += "/META-INF/LICENSE.txt"
            excludes += "/META-INF/NOTICE"
            excludes += "/META-INF/NOTICE.txt"
            excludes += "/META-INF/notice.txt"
            excludes += "/META-INF/DEPENDENCIES.txt"
            excludes += "/META-INF/gradle/incremental.annotation.processors"
            excludes += "/META-INF/*.kotlin_module"
            excludes += "/kotlin/**"
            excludes += "/kotlin_metadata/**"
            excludes += "/jsr305/**"
            excludes += "/animal_sniffer/**"
            excludes += "/javax/annotation/**"
            excludes += "/org/**"
            excludes += "/okhttp3/**"
            excludes += "/com/google/**"
            excludes += "/com/squareup/**"
            excludes += "DebugProbesKt.bin"
        }

        // Exclude duplicate files
        jniLibs {
            pickFirsts += "**/libc++_shared.so"
            pickFirsts += "**/libjsc.so"
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    androidComponents {
        beforeVariants(selector().withBuildType("release")) {
            it.enableAndroidTest = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.9.0"))
    implementation("com.google.firebase:firebase-analytics")

    // HomeWidget dependency removed due to compatibility issues
    // implementation("es.antonborri.home_widget:home_widget:0.7.1")
}
