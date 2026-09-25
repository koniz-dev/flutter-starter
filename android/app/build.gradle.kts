import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material. Never committed: android/.gitignore already ignores
// key.properties, **/*.jks and **/*.keystore. The CI recipe that writes this
// file is the "Setup Android keystore" step in
// .github/workflows/deploy-android.yml.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val allowUnsignedRelease = (project.findProperty("allowUnsignedRelease") as String?) == "true"

val releaseKeystore: File? =
    if (!keystorePropertiesFile.exists()) {
        null
    } else {
        val missing =
            listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "android/key.properties is missing required keys: " +
                    missing.joinToString(", "),
            )
        }
        val declared = File(keystoreProperties.getProperty("storeFile"))
        // Flutter's documented recipe writes `storeFile=upload-keystore.jks`
        // next to key.properties, i.e. relative to android/ - not relative to
        // android/app/, which is what a bare `file(...)` in this script means.
        val resolved = if (declared.isAbsolute) declared else rootProject.file(declared.path)
        if (!resolved.exists()) {
            throw GradleException(
                "android/key.properties points at a keystore that does not exist: " +
                    resolved.absolutePath,
            )
        }
        resolved
    }

android {
    namespace = "com.example.flutter_starter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_starter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Patrol E2E (integration_test/). Required for the androidTest source
        // set to be discovered; without it `patrol test` collects 0 tests and
        // still exits 0. Harmless for normal app builds.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    // Patrol runs each Dart test in a fresh process via the AndroidX test
    // orchestrator, so state does not leak between tests.
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Deliberately NOT signingConfigs.getByName("debug"). A debug-signed
            // bundle builds fine everywhere and is then rejected by Play Console
            // with "You uploaded an APK or Android App Bundle that was signed in
            // debug mode", long after the green CI run that produced it.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Fail at the moment a release artifact is actually requested rather than at
// configure time, so `flutter test`, `flutter analyze` and every debug build
// keep working on a machine with no keystore.
if (releaseKeystore == null && !allowUnsignedRelease) {
    gradle.taskGraph.whenReady {
        val wantsRelease =
            allTasks.any { task ->
                task.name.contains("Release") &&
                    (
                        task.name.startsWith("assemble") ||
                            task.name.startsWith("bundle") ||
                            task.name.startsWith("package")
                    )
            }
        if (wantsRelease) {
            throw GradleException(
                """
                Release signing is not configured, so this build would produce an
                unsigned (previously: debug-signed) artifact. Refusing.

                Create android/key.properties:
                    storeFile=upload-keystore.jks   # relative to android/, or absolute
                    storePassword=...
                    keyAlias=...
                    keyPassword=...

                Generate a keystore with:
                    keytool -genkey -v -keystore android/upload-keystore.jks \
                      -keyalg RSA -keysize 2048 -validity 10000 -alias upload

                In CI see the "Setup Android keystore" step in
                .github/workflows/deploy-android.yml.

                To build an UNSIGNED release anyway - local smoke tests only, the
                artifact cannot be installed or uploaded - pass:
                    flutter build apk --release -PallowUnsignedRelease=true
                """.trimIndent(),
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Test-only: pulled in for androidTest variants, not shipped in the app.
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
