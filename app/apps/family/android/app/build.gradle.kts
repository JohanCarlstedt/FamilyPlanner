import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing, per architecture doc §18. key.properties and the keystore are
// gitignored; see secrets/ in the repo root. Missing keys fail release builds
// loudly rather than falling back to the debug key, because a build signed with
// the wrong key can't be upgraded in place on family devices.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// The Google Maps key for the family map. Gitignored like the keystore: it is
// billable and tied to this project. Missing, the map tiles stay blank and the
// rest of the app is unaffected, so debug builds work without one.
val mapsProperties = Properties().apply {
    val file = rootProject.file("maps.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "io.github.johancarlstedt.family"
    // receive_sharing_intent (the share sheet) compiles against 37; the
    // Flutter default is a version behind.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time on older Androids.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Permanent once published to Play. Changing it means every tester
        // reinstalls and loses their unsynced command queue.
        applicationId = "io.github.johancarlstedt.family"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        manifestPlaceholders["MAPS_API_KEY"] =
            mapsProperties.getProperty("mapsApiKey") ?: ""
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        // Needed for the per-flavour app_name below.
        resValues = true
    }

    signingConfigs {
        create("release") {
            if (keyProperties.isNotEmpty()) {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    // dev and prod install side by side on one phone. Family testing uses prod
    // builds signed with the release key, so the upgrade path to Play is straight.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Family Planner Dev")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Family Planner")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter { it.project == project && it.name.contains("Release") }
    if (releaseTasks.isNotEmpty() && keyProperties.isEmpty) {
        throw GradleException(
            "Release builds need android/key.properties and the release keystore " +
                "(architecture doc §18). Use a debug build, or add the key."
        )
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
