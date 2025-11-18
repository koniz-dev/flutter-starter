# Deployment Quick Start

Get started with deploying Flutter Starter in 5 minutes.

## Prerequisites Checklist

- [ ] Flutter SDK installed (`flutter --version`)
- [ ] Android Studio / Xcode installed (for mobile)
- [ ] Google Play Developer account (Android) - $25 one-time
- [ ] Apple Developer account (iOS) - $99/year
- [ ] GitHub repository with Actions enabled
- [ ] Firebase account (for monitoring/analytics)

## Step 1: Code Signing Setup (5 minutes)

### Android

1. Generate keystore:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Create `android/key.properties`:
```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

3. Update `android/app/build.gradle.kts` (see [android-deployment.md](./android-deployment.md))

### iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner → Signing & Capabilities
3. Enable "Automatically manage signing"
4. Select your Team

## Step 2: Configure GitHub Secrets (10 minutes)

Go to GitHub → Settings → Secrets and variables → Actions

### Required Secrets

**Android:**
- `ANDROID_KEYSTORE_BASE64`: `base64 ~/upload-keystore.jks | pbcopy`
- `ANDROID_KEYSTORE_PASSWORD`: Your keystore password
- `ANDROID_KEY_ALIAS`: `upload`
- `ANDROID_KEY_PASSWORD`: Your key password
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Service account JSON

**iOS:**
- `APPLE_TEAM_ID`: Your Apple Team ID
- `APP_STORE_CONNECT_API_KEY_ID`: API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: Issuer ID
- `APP_STORE_CONNECT_API_KEY_BASE64`: Base64-encoded .p8 key

**Web:**
- `FIREBASE_PROJECT_ID`: Your Firebase project ID
- `FIREBASE_SERVICE_ACCOUNT_KEY`: Service account JSON

**General:**
- `BASE_URL_STAGING`: `https://api-staging.example.com`
- `BASE_URL_PRODUCTION`: `https://api.example.com`

## Step 3: Test Local Build (5 minutes)

```bash
# Android
flutter build appbundle --release --flavor production

# iOS
flutter build ipa --release

# Web
flutter build web --release
```

## Step 4: Create Your First Release (5 minutes)

```bash
# Bump version
./scripts/bump_version.sh patch

# Generate changelog
./scripts/generate_changelog.sh

# Create release (automated)
./scripts/release.sh patch
```

Or manually:
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## Step 5: Monitor Deployment

1. Check GitHub Actions tab
2. Monitor build progress
3. Verify deployment in stores/hosting

## Next Steps

- Read [deployment.md](./deployment.md) for detailed instructions
- Set up [Monitoring & Analytics](./monitoring-analytics.md)
- Review [Release Process](./release-process.md)

## Troubleshooting

**Build fails?**
- Check Flutter version: `flutter --version`
- Clean build: `flutter clean && flutter pub get`
- Verify environment variables

**Code signing fails?**
- Verify keystore/certificate exists
- Check passwords are correct
- Ensure certificates haven't expired

**CI/CD fails?**
- Verify all secrets are set
- Check workflow logs
- Ensure runner has required tools

## Resources

- [Main Deployment Guide](./deployment.md)
- [Android Guide](./android-deployment.md)
- [iOS Guide](./ios-deployment.md)
- [Web Guide](./web-deployment.md)

