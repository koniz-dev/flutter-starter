# Android Deployment Guide

Complete guide for deploying Flutter Starter to Google Play Store.

## Prerequisites

- Google Play Developer account ($25 one-time fee)
- Android Studio installed
- Flutter SDK installed
- Java Development Kit (JDK) 17 or later

## Step 1: Create Google Play Developer Account

1. Go to [Google Play Console](https://play.google.com/console)
2. Sign up for a developer account
3. Pay the one-time registration fee
4. Complete your developer profile

## Step 2: Create App in Play Console

1. Click "Create app"
2. Fill in app details:
   - **App name**: Your app name
   - **Default language**: English (or your primary language)
   - **App or game**: App
   - **Free or paid**: Choose your model
3. Accept the declarations
4. Create the app

## Step 3: Set Up Code Signing

### Generate Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

You'll be prompted for:
- Keystore password
- Key password (can be same as keystore)
- Your name and organization details

**Important**: Save these passwords securely! You'll need them for every release.

### Create key.properties

Create `android/key.properties` (add to `.gitignore`):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

### Update build.gradle.kts

Update `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        applicationId = "com.example.flutter_starter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Flutter Starter Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Flutter Starter Staging")
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "Flutter Starter")
        }
    }
}

flutter {
    source = "../.."
}
```

### Create ProGuard Rules

Create `android/app/proguard-rules.pro`:

```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
```

## Step 4: Configure App Bundle

### Build App Bundle

```bash
flutter build appbundle \
  --flavor production \
  --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BASE_URL=https://api.example.com
```

Output: `build/app/outputs/bundle/productionRelease/app-production-release.aab`

### Test App Bundle Locally

```bash
# Install bundletool
# Download from: https://github.com/google/bundletool/releases

# Generate APKs from bundle
bundletool build-apks \
  --bundle=build/app/outputs/bundle/productionRelease/app-production-release.aab \
  --output=app.apks \
  --ks=~/upload-keystore.jks \
  --ks-pass=pass:YOUR_STORE_PASSWORD \
  --ks-key-alias=upload \
  --key-pass=pass:YOUR_KEY_PASSWORD

# Install on device
bundletool install-apks --apks=app.apks
```

## Step 5: Prepare Store Listing

### Required Assets

1. **App Icon**: 512x512px PNG (no transparency)
2. **Feature Graphic**: 1024x500px PNG
3. **Screenshots**: 
   - Phone: At least 2, up to 8 (16:9 or 9:16)
   - Tablet (7"): At least 1 (optional)
   - Tablet (10"): At least 1 (optional)
4. **Promo Video**: YouTube link (optional)

### Store Listing Information

1. **Short description**: 80 characters max
2. **Full description**: 4000 characters max
3. **App category**: Select appropriate category
4. **Content rating**: Complete questionnaire
5. **Privacy policy**: Required URL
6. **Contact details**: Email and website

## Step 6: Upload to Play Console

### Manual Upload

1. Go to Play Console → Your App → Production
2. Click "Create new release"
3. Upload the `.aab` file
4. Add release notes:
   ```
   What's new in this version:
   - Feature 1
   - Bug fixes
   - Performance improvements
   ```
5. Review release
6. Start rollout (staged or full)

### Automated Upload (CI/CD)

See [CI/CD Pipeline](../deployment.md#cicd-pipeline) for automated upload using GitHub Actions workflows.

## Step 7: Testing Tracks

### Internal Testing

1. Create internal test track
2. Upload APK/AAB
3. Add testers (up to 100)
4. Testers receive email with opt-in link

### Closed Testing (Alpha/Beta)

1. Create alpha or beta track
2. Upload APK/AAB
3. Create test group
4. Add testers via email or Google Groups
5. Testers can opt-in via Play Store link

### Open Testing

1. Create open beta track
2. Upload APK/AAB
3. Anyone can join via Play Store
4. Good for large-scale testing

## Step 8: Production Release

### Pre-Release Checklist

- [ ] App tested on multiple devices
- [ ] All store listing assets uploaded
- [ ] Privacy policy URL set
- [ ] Content rating completed
- [ ] App bundle signed correctly
- [ ] Version code incremented
- [ ] Release notes written

### Rollout Strategy

**Staged Rollout** (Recommended):
- Start with 20% of users
- Monitor crash reports and reviews
- Gradually increase to 100%

**Full Rollout**:
- Release to 100% immediately
- Use for critical bug fixes

## Step 9: Post-Release Monitoring

### Monitor in Play Console

1. **Crashes & ANRs**: Check for issues
2. **User reviews**: Respond to feedback
3. **Performance**: Monitor app performance metrics
4. **Acquisition**: Track installs and uninstalls

### Update Process

1. Fix issues found in production
2. Increment version code in `pubspec.yaml`
3. Build new app bundle
4. Upload to production track
5. Add release notes
6. Rollout update

## Troubleshooting

### Build Errors

**"Keystore file not found"**:
- Verify path in `key.properties`
- Use absolute path for `storeFile`

**"Signing config not found"**:
- Ensure `signingConfigs` block is before `buildTypes`
- Verify keystore properties are loaded

### Upload Errors

**"Version code already used"**:
- Increment `versionCode` in `pubspec.yaml`
- Rebuild app bundle

**"App not signed"**:
- Verify signing config is applied
- Check keystore file exists and is valid

### Play Console Issues

**"App rejected"**:
- Check email for specific reason
- Address all policy violations
- Resubmit after fixes

## Best Practices

1. **Always use App Bundle**: Smaller download sizes
2. **Test on multiple devices**: Different screen sizes and Android versions
3. **Staged rollouts**: Start small, expand gradually
4. **Monitor metrics**: Track crashes, ANRs, and user feedback
5. **Regular updates**: Keep app updated with bug fixes and features
6. **Security**: Never commit keystore or passwords to git

## Resources

- [Google Play Console](https://play.google.com/console)
- [App Bundle Guide](https://developer.android.com/guide/app-bundle)
- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)

