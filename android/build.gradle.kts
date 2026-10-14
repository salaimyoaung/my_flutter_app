allprojects {
    repositories {
        google()
        mavenCentral()
    }
    extra["kotlin_version"] = "2.2.20"
    extra["compileSdk"] = 36
    extra["minSdk"] = 21
    extra["targetSdk"] = 36
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
