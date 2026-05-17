allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val kotlin_version = "2.3.0"

subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                compileSdkVersion(36)
                defaultConfig {
                    targetSdk = 36
                }

                // Force Java 17 for all library modules (fixes flutter_timezone error)
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
            
            // Sync Java and Kotlin task targets
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "17"
                targetCompatibility = "17"
            }
        }
    }

    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion(kotlin_version)
            }
        }
    }
}

allprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(layout.buildDirectory)
}