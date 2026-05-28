import com.android.build.gradle.BaseExtension

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
}

// --- OUR OVERRIDE BLOCK IS NOW MOVED HERE ---
subprojects {
    afterEvaluate {
        // Check if the plugin is an Android plugin
        if (extensions.findByName("android") != null) {
            // Force it to use API 36
            (extensions.getByName("android") as BaseExtension).compileSdkVersion(36)
        }
    }
}
// --------------------------------------------

// Now Flutter can evaluate the app safely
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}