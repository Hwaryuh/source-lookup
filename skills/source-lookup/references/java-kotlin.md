# Java and Kotlin

## Pin the version

- Gradle: `./gradlew -q dependencyInsight --dependency <artifact> --configuration compileClasspath`.
  In a multi-module build, prefix the task with the module path:
  `./gradlew -q :<module>:dependencyInsight ...`.
- Maven: `mvn -q dependency:tree -Dincludes=<group>:<artifact>`.

A cache usually holds several versions of the same artifact. The version the build selected is the
only one that counts.

## Find the files

- Gradle cache root: `$GRADLE_USER_HOME`, or `~/.gradle` when the variable is not set.
  Artifacts are in `caches/modules-2/files-2.1/<group>/<artifact>/<version>/<sha1>/<file>`.
  Each file sits in its own hash folder. The `-sources.jar` file is usually in a different hash
  folder from the main jar, so search the whole `<version>` folder.
- Maven cache: `~/.m2/repository/<group as path>/<artifact>/<version>/`.
- `locate.ps1 -Lang java -Package <group>:<artifact>` lists the cached versions with their jars and
  sources jars.

## Signatures

`javap -p -cp <jar> <fully.qualified.ClassName>` prints members without any source. Add `-c` only
when you need bytecode.

For Kotlin, javap shows the JVM view: `Companion` objects, `$default` bridges, top-level functions
in `<File>Kt` classes, and `internal` members with mangled names. Read the Kotlin source when the
Kotlin-level shape matters (default arguments, extension receivers, nullability).

## Source

Read classes directly from the `-sources.jar` file. A jar is a zip file: list its entries and extract
only the class you need into the cache.

If no sources jar is in the cache, download it without changing the project. This needs network
access and the user's approval:

```
./gradlew -q --init-script <skill dir>/scripts/gradle-sources.init.gradle sourceLookupSources -PsourceLookupFilter=<artifact>
```

The task resolves the `compileClasspath`, `runtimeClasspath` and `testCompileClasspath`
configurations of every project. It downloads the matching `-sources.jar` files into the Gradle
cache and prints their paths. It changes no project files.

Maven: `mvn dependency:sources -DincludeArtifactIds=<artifact>`.

## No source published

Decompile with Vineflower. Find it with `decompiler.ps1 -Tool vineflower`. Extract the classes you
need from the jar first, then run `java -jar <vineflower.jar> <class or jar> <output dir>`. Put the
output in the cache, not in the project, and reuse it.

## Traps

- Shaded or relocated dependencies: the class lives under a relocated package inside another jar.
- Remapped or obfuscated game or engine jars: use the project's own reference setup if it has one.
- `@Deprecated(forRemoval = true)` and `@ApiStatus` annotations are visible only in the source or with
  `javap -v`.
- Kotlin `inline` and `reified` functions do not exist as callable JVM methods the way javap suggests.

## Check

Run the project's compile task, for example `./gradlew compileJava` or `./gradlew compileKotlin`.
