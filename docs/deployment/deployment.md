# Deployment Documentation

Complete guide for deploying Flutter Starter across Android (Play Store), iOS (App Store), and Web platforms.

## Table of Contents

1. [Build Configuration](#build-configuration)
2. [CI/CD Pipeline](#cicd-pipeline)
3. [Release Process](#release-process)
4. [Monitoring & Analytics](#monitoring--analytics)
5. [Platform-Specific Guides](#platform-specific-guides)

---

## Build Configuration

### Environment Setup

The project supports three environments: `development`, `staging`, and `production`.

#### Environment Variables

Create environment-specific configuration files:

**`.env.development`**
```env
ENVIRONMENT=development
BASE_URL=http://localhost:3000
ENABLE_LOGGING=true
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
ENABLE_PERFORMANCE_MONITORING=false
ENABLE_DEBUG_FEATURES=true
ENABLE_HTTP_LOGGING=true
```

**`.env.staging`**
```env
ENVIRONMENT=staging
BASE_URL=https://api-staging.example.com
ENABLE_LOGGING=true
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
ENABLE_PERFORMANCE_MONITORING=true
ENABLE_DEBUG_FEATURES=false
ENABLE_HTTP_LOGGING=false
```

**`.env.production`**
```env
ENVIRONMENT=production
BASE_URL=https://api.example.com
ENABLE_LOGGING=false
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
ENABLE_PERFORMANCE_MONITORING=true
ENABLE_DEBUG_FEATURES=false
ENABLE_HTTP_LOGGING=false
```

### Flavor Configuration

#### Android Flavors

Update `android/app/build.gradle.kts`:

```kotlin
android {
    // ... existing configuration ...

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
```

#### iOS Schemes

Create Xcode schemes for each environment:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Product → Scheme → Manage Schemes
3. Duplicate the "Runner" scheme for each environment:
   - `Runner-Development`
   - `Runner-Staging`
   - `Runner-Production`

For each scheme, configure:
- **Build Configuration**: Debug/Release
- **Environment Variables**: Add `ENVIRONMENT=development|staging|production`

### Code Signing Setup

#### Android

1. **Generate Keystore**:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. **Create `android/key.properties`** (add to `.gitignore`):
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to-keystore>/upload-keystore.jks
```

3. **Update `android/app/build.gradle.kts`**:
```kotlin
// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing configuration ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
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
}
```

4. **Create `android/app/proguard-rules.pro`**:
```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
```

#### iOS

1. **Create App ID** in [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)

2. **Create Provisioning Profiles**:
   - Development: For development builds
   - Ad Hoc: For internal testing
   - App Store: For App Store distribution

3. **Configure Signing in Xcode**:
   - Open `ios/Runner.xcworkspace`
   - Select Runner target → Signing & Capabilities
   - Enable "Automatically manage signing"
   - Select your Team
   - Xcode will automatically manage certificates and profiles

4. **Manual Signing (if needed)**:
   - Disable "Automatically manage signing"
   - Select provisioning profiles for each configuration

### Build Commands

#### Android

**Development APK**:
```bash
flutter build apk --flavor development --dart-define=ENVIRONMENT=development
```

**Staging APK**:
```bash
flutter build apk --flavor staging --dart-define=ENVIRONMENT=staging --dart-define=BASE_URL=https://api-staging.example.com
```

**Production APK**:
```bash
flutter build apk --flavor production --release --dart-define=ENVIRONMENT=production --dart-define=BASE_URL=https://api.example.com
```

**Production App Bundle (for Play Store)**:
```bash
flutter build appbundle --flavor production --release --dart-define=ENVIRONMENT=production --dart-define=BASE_URL=https://api.example.com
```

#### iOS

**Development**:
```bash
flutter build ios --flavor development --dart-define=ENVIRONMENT=development --no-codesign
```

**Staging**:
```bash
flutter build ios --flavor staging --release --dart-define=ENVIRONMENT=staging --dart-define=BASE_URL=https://api-staging.example.com
```

**Production (for App Store)**:
```bash
flutter build ipa --flavor production --release --dart-define=ENVIRONMENT=production --dart-define=BASE_URL=https://api.example.com
```

#### Web

**Development**:
```bash
flutter build web --dart-define=ENVIRONMENT=development --dart-define=BASE_URL=http://localhost:3000
```

**Staging**:
```bash
flutter build web --release --dart-define=ENVIRONMENT=staging --dart-define=BASE_URL=https://api-staging.example.com
```

**Production**:
```bash
flutter build web --release --dart-define=ENVIRONMENT=production --dart-define=BASE_URL=https://api.example.com
```

---

## CI/CD Pipeline

The project includes automated CI/CD workflows for:
- **Continuous Integration**: Run tests on every push/PR
- **Automated Builds**: Build artifacts for all platforms
- **Automated Deployment**: Deploy to stores/hosting

### GitHub Actions Workflows

All workflows are located in `.github/workflows/` and are **disabled by default** (all triggers commented out) to prevent automatic execution in template repositories.

**Available Workflows:**
- `ci.yml` - Continuous Integration (format, analyze, test, build)
- `test.yml` - Dedicated test workflow with coverage
- `coverage.yml` - Coverage analysis and reporting
- `deploy-android.yml` - Android deployment to Play Store
- `deploy-ios.yml` - iOS deployment to App Store
- `deploy-web.yml` - Web deployment to hosting platforms

**Configuration:**

1. **Enable workflows** - Uncomment trigger configuration in workflow files:
   ```yaml
   on:
     # Uncomment the triggers you want to enable:
     push:
       branches: [ main, develop ]  # Uncomment and configure
     pull_request:
       branches: [ main, develop ]  # Uncomment and configure
     # workflow_dispatch is enabled by default for manual triggers
   ```
   
   **Note:** All `push` and `pull_request` triggers are commented out by default. Workflows will only run via `workflow_dispatch` (manual trigger) until you uncomment the triggers.

2. **Configure secrets** - Add required secrets in GitHub Settings → Secrets and variables → Actions:

   **For Testing:**
   - `CODECOV_TOKEN` (for private repos)

   **For Android Deployment:**
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

   **For iOS Deployment:**
   - `APPLE_TEAM_ID`
   - `APP_STORE_CONNECT_API_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_API_KEY_BASE64`

   **For Web Deployment:**
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_SERVICE_ACCOUNT_KEY`

3. **Codecov Setup** (for private repos):
   - Sign up at https://codecov.io
   - Add repository and get token
   - Add `CODECOV_TOKEN` to GitHub Secrets
   - Workflows are pre-configured for private repos

---

## Release Process

### Version Management

The app version is defined in `pubspec.yaml`:
```yaml
version: 1.0.0+1
```
Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes
- **BUILD_NUMBER**: Incremental build number (required by stores)

### Version Bumping

Use the provided script:
```bash
./scripts/bump_version.sh [major|minor|patch] [build_number]
```

Examples:
```bash
# Bump patch version
./scripts/bump_version.sh patch

# Bump minor version
./scripts/bump_version.sh minor

# Bump major version
./scripts/bump_version.sh major

# Set specific build number
./scripts/bump_version.sh patch 42
```

### Changelog Generation

Changelogs are automatically generated from git commits. Use conventional commit format:

```
feat: Add new feature
fix: Fix bug
docs: Update documentation
style: Code style changes
refactor: Code refactoring
test: Add tests
chore: Maintenance tasks
```

Generate changelog:
```bash
./scripts/generate_changelog.sh
```

### Pre-Release Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Update `CHANGELOG.md`
- [ ] Run all tests: `flutter test`
- [ ] Run linting: `flutter analyze`
- [ ] Test on all platforms (Android, iOS, Web)
- [ ] Update dependencies: `flutter pub upgrade`
- [ ] Verify environment variables
- [ ] Create release branch: `git checkout -b release/v1.0.0`
- [ ] Tag release: `git tag -a v1.0.0 -m "Release v1.0.0"`

### Build Artifacts

#### Android
- **APK**: `build/app/outputs/flutter-apk/app-production-release.apk`
- **App Bundle**: `build/app/outputs/bundle/productionRelease/app-production-release.aab`

#### iOS
- **IPA**: `build/ios/ipa/Runner.ipa`

#### Web
- **Web Build**: `build/web/`

### Store Submission

#### Google Play Store

1. **Create Release in Play Console**:
   - Go to [Google Play Console](https://play.google.com/console)
   - Select your app → Production → Create new release
   - Upload the `.aab` file

2. **Release Notes**:
   - Add release notes for users
   - Include what's new in this version

3. **Review and Rollout**:
   - Review all information
   - Start rollout (staged or full)

#### Apple App Store

1. **Archive in Xcode**:
   ```bash
   # Or use CI/CD to build IPA
   flutter build ipa --release
   ```

2. **Upload via Transporter or Xcode**:
   - Open Xcode → Window → Organizer
   - Select archive → Distribute App
   - Choose App Store Connect
   - Follow the wizard

3. **Submit for Review**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Select your app → Prepare for Submission
   - Fill in all required information
   - Submit for review

#### Web Hosting

**Firebase Hosting**:
```bash
firebase deploy --only hosting
```

**Other Hosting Providers**:
- Upload `build/web/` directory to your hosting service
- Configure routing for SPA (all routes → `index.html`)

---

## Monitoring & Analytics

### Firebase Crashlytics Setup

1. **Add Dependencies** to `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_crashlytics: ^4.0.0
```

2. **Initialize in `main.dart`**:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // ... rest of initialization
}
```

3. **Configure Firebase Projects**:
   - Create Firebase projects for each environment
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - **Note:** These files are gitignored. For CI/CD (e.g., GitHub Actions), store them as Base64 secrets (`ANDROID_GOOGLE_SERVICES_JSON`, `IOS_GOOGLE_SERVICE_INFO`) and decode them during the build process.
   - Place in appropriate flavor directories

### Analytics Integration

**Firebase Analytics**:
```dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// Track events
await analytics.logEvent(
  name: 'button_click',
  parameters: {'button_name': 'submit'},
);
```

**Custom Analytics**:
```dart
// In your analytics service
if (AppConfig.enableAnalytics) {
  await analyticsService.trackEvent('event_name', parameters);
}
```

### Performance Monitoring

**Firebase Performance**:
```dart
import 'package:firebase_performance/firebase_performance.dart';

final trace = FirebasePerformance.instance.newTrace('api_call');
await trace.start();

// Your API call
await apiService.fetchData();

await trace.stop();
```

---

## Platform-Specific Guides

### Android Deployment

See [android-deployment.md](./android-deployment.md) for detailed Android-specific deployment instructions.

### iOS Deployment

See [ios-deployment.md](./ios-deployment.md) for detailed iOS-specific deployment instructions.

### Web Deployment

See [web-deployment.md](./web-deployment.md) for detailed Web-specific deployment instructions.

---

## Troubleshooting

### Common Issues

**Build Failures**:
- Check Flutter version: `flutter --version`
- Clean build: `flutter clean && flutter pub get`
- Check environment variables are set correctly

**Code Signing Issues**:
- Verify keystore/certificate files exist
- Check passwords are correct
- Ensure certificates haven't expired

**CI/CD Failures**:
- Verify all secrets are set in GitHub (see Required Secrets section above)
- Check workflow logs for specific errors
- Ensure runner has required tools installed
- **Workflows are disabled by default** - Uncomment `push` and `pull_request` triggers in workflow files to enable automatic runs
- Verify GitHub Actions is enabled in repository settings

### Getting Help

- Check [Troubleshooting Guide](../guides/support/troubleshooting.md)
- Review workflow logs in GitHub Actions tab
- Check platform-specific deployment guides

---

## Next Steps

1. Set up code signing for Android and iOS
2. Configure GitHub Actions secrets (see Required Secrets section above)
3. Set up Firebase projects for each environment
4. Test build process locally
5. Create first release

