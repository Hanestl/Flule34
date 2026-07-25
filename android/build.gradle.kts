import java.io.File

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
    val workspaceRoot = rootProject.projectDir.toPath().root?.toString()
    val projectRoot = project.projectDir.toPath().root?.toString()
    val sameRoot = workspaceRoot != null &&
        projectRoot != null &&
        workspaceRoot.equals(projectRoot, ignoreCase = true)
    if (sameRoot) {
        project.layout.buildDirectory.value(newBuildDir.dir(project.name))
    } else {
        // Windows 不允许 Gradle Lint 在不同盘符之间计算相对路径。
        val localAppData = System.getenv("LOCALAPPDATA")?.let(::File)
        val localAppDataRoot = localAppData?.toPath()?.root?.toString()
        val cacheRoot = if (
            localAppData != null &&
                projectRoot != null &&
                localAppDataRoot != null &&
                localAppDataRoot.equals(projectRoot, ignoreCase = true)
        ) {
            File(
                localAppData,
                "Flule34/gradle-build/${rootProject.projectDir.absolutePath.hashCode()}",
            )
        } else {
            File(project.projectDir, "build")
        }
        project.layout.buildDirectory.value(
            project.layout.projectDirectory.dir(
                project.projectDir.toPath().relativize(
                    File(cacheRoot, project.name).toPath(),
                ).toString(),
            ),
        )
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(subprojects.map { it.layout.buildDirectory })
}
