plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.file_logger20"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.file_logger20"
        minSdk = flutter.minSdkVersion
        targetSdk = 33//flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = "File Logger 2.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../../"
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:$embeddedKotlinVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("com.squareup.okhttp3:okhttp:4.11.0")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation ("commons-net:commons-net:3.8.0")
    implementation ("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.1.0")
    implementation ("com.squareup.retrofit2:retrofit:2.9.0")
    implementation ("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation ("androidx.work:work-runtime-ktx:2.8.1")
    implementation ("com.google.android.material:material:1.12.0") // Material Design компоненты
    implementation ("androidx.constraintlayout:constraintlayout:2.2.1") // ConstraintLayout
    implementation ("commons-net:commons-net:3.9.0")
    implementation ("org.jetbrains.kotlinx:kotlinx-serialization-json:1.5.1")
    implementation ("androidx.core:core-ktx:1.7.0")
    implementation ("com.jakewharton.timber:timber:5.0.1") // используем последнюю версию


}