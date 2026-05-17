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

val keystoreProps = Properties()
val keystorePropsFile = rootProject.file("key.properties")
if (keystorePropsFile.exists()) {
    keystoreProps.load(FileInputStream(keystorePropsFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProps["keyAlias"] as? String
                ?: error("keyAlias missing from android/key.properties")
            keyPassword = keystoreProps["keyPassword"] as? String
                ?: error("keyPassword missing from android/key.properties")
            storeFile = (keystoreProps["storeFile"] as? String)?.let { file(it) }
                ?: error("storeFile missing from android/key.properties")
            storePassword = keystoreProps["storePassword"] as? String
                ?: error("storePassword missing from android/key.properties")
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
        versionCode = 16
        versionName = "1.0.0"
    }

    buildTypes {
        release {
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
            
            // Disable Crashlytics mapping file upload to avoid network issues
            manifestPlaceholders["crashlyticsCollectionEnabled"] = "false"
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
            
            // Disable Crashlytics mapping file upload to avoid network issues
            manifestPlaceholders["crashlyticsCollectionEnabled"] = "false"
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
