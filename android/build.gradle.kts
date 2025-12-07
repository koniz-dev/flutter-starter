plugins {
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Configure Java toolchain for all subprojects (including firebase plugins)
    afterEvaluate {
        if (project.plugins.hasPlugin("java") || project.plugins.hasPlugin("com.android.library")) {
            project.extensions.findByType<JavaPluginExtension>()?.apply {
                toolchain {
                    languageVersion.set(JavaLanguageVersion.of(17))
                }
            }
        }
    }
}

// Ensure :app is evaluated before other projects to initialize Google Services
subprojects {
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
