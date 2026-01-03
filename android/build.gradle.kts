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

// Auto-assign namespace to plugins that don't have one
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.let { android ->
                if (android.namespace == null) {
                    val autoNamespace = when (project.name) {
                        "flutter_bluetooth_serial" -> "com.github.edufolly.flutterbluetoothserial"
                        else -> "com.example.${project.name.replace("-", "_").replace(".", "_")}"
                    }
                    android.namespace = autoNamespace
                    println("⚠️  Auto-assigned namespace '$autoNamespace' to ${project.name}")
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}