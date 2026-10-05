allprojects {
    repositories {
        // Keep IDE and terminal builds on the same Flutter engine mirror.
        // Limit this repository to engine artifacts; Android libraries use below.
        maven {
            url = uri("https://storage.flutter-io.cn/download.flutter.io")
            content { includeGroup("io.flutter") }
        }
// 添加阿里云镜像加速下载
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
