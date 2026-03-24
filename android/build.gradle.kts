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
subprojects {
    project.evaluationDependsOn(":app")
    
    // Workaround for AGP 8+ namespace requirement for older Flutter plugins
    afterEvaluate {
        if (hasProperty("android")) {
            val androidExt = project.extensions.getByName("android")
            try {
                val namespaceExt = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (namespaceExt == null || namespaceExt.toString().isEmpty()) {
                    androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        .invoke(androidExt, project.group.toString())
                }
            } catch (e: Exception) {
                // Ignore if method doesn't exist or fails
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
