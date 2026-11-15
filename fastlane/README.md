# Fastlane Setup

Fastlane is configured for automated deployment to both Google Play Store (Android) and App Store Connect (iOS).

## 📁 Structure

```
fastlane/
├── Fastfile          # Android deployment lanes
├── Appfile           # Android app configuration
└── metadata/         # Play Store metadata (screenshots, descriptions, etc.)
    └── android/
        └── en-US/
            └── changelogs/
                └── default.txt

ios/fastlane/
├── Fastfile          # iOS deployment lanes
└── Appfile           # iOS app configuration
```

## 🚀 Quick Start

### Prerequisites

1. **Install Fastlane**:
   ```bash
   # macOS (for iOS)
   sudo gem install fastlane
   
   # Or using Homebrew
   brew install fastlane
   
   # Linux/Windows (for Android only)
   gem install fastlane
   ```

2. **Configure Appfile**:
   - Update `fastlane/Appfile` with your Android package name
   - Update `ios/fastlane/Appfile` with your iOS bundle ID and Team ID

Every build and upload lane below needs your certificate fingerprints for a
staging or production build - add `ssl_fingerprints:<list>` or set
`API_SSL_FINGERPRINTS` - or it stops before building. See
[Certificate pinning](#certificate-pinning).

### Android Deployment

Run these commands from the repository root. Fastlane discovers
`fastlane/Fastfile`; the iOS examples below use a subshell in `ios/`.

#### Build App Bundle
```bash
fastlane android build_bundle environment:production
```

#### Upload to Play Store
```bash
# Internal track
fastlane android upload_internal environment:staging

# Alpha track
fastlane android upload_alpha environment:staging

# Beta track
fastlane android upload_beta environment:staging

# Production track
fastlane android upload_production environment:production
```

#### Custom track
```bash
fastlane android upload environment:production track:beta
```

### iOS Deployment

#### Build IPA
```bash
(cd ios && fastlane ios build_appstore environment:production)
```

#### Upload to TestFlight
```bash
(cd ios && fastlane ios upload_testflight environment:staging)
```

#### Upload to App Store
```bash
(cd ios && fastlane ios upload_appstore environment:production)
```

#### Submit for Review
```bash
(cd ios && fastlane ios release environment:production)
```

## 📋 Available Lanes

### Android Lanes

| Lane | Description |
|------|-------------|
| `build_bundle` | Build App Bundle (.aab) |
| `build_apk` | Build APK for testing |
| `upload_internal` | Upload to Internal track |
| `upload_alpha` | Upload to Alpha track |
| `upload_beta` | Upload to Beta track |
| `upload_production` | Upload to Production track |
| `upload` | Upload with automatic track selection |
| `version` | Show current version |
| `test` | Run Flutter tests |
| `analyze` | Run Flutter analyze |

### iOS Lanes

| Lane | Description |
|------|-------------|
| `build_appstore` | Build IPA for App Store |
| `build_adhoc` | Build IPA for Ad Hoc distribution |
| `upload_appstore` | Upload to App Store Connect |
| `upload_testflight` | Upload to TestFlight |
| `release` | Upload and submit for review |
| `version` | Show current version |
| `test` | Run Flutter tests |
| `analyze` | Run Flutter analyze |

## ⚙️ Configuration

### Android Configuration

Edit `fastlane/Appfile`:
```ruby
package_name("com.example.flutter_starter") # Your package name
```

### iOS Configuration

Edit `ios/fastlane/Appfile`:
```ruby
team_id("YOUR_TEAM_ID") # Your Apple Team ID
app_identifier("com.example.flutterStarter") # Your bundle ID
```

## 🔐 Authentication

### Google Play Store

You need a Google Play Service Account JSON file. See [Android Deployment Guide](../docs/deployment/android-deployment.md) for setup instructions.

Options:
1. Set `json_key_file` in `Appfile` (a path to the JSON file)
2. Set `json_key_data_raw` in `Appfile` (the JSON itself, for CI/CD)
3. Set `SUPPLY_JSON_KEY` (a path) or `SUPPLY_JSON_KEY_DATA` (the JSON) in the
   environment - `upload_to_play_store` reads both by itself. To use another
   variable such as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, add
   `json_key_data: ENV["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"]` to each
   `upload_to_play_store` call used by your lanes. The commented example in
   `upload_internal` shows this option; the other lanes need it added too.

### App Store Connect

You can use either:
1. **App Store Connect API Key** (recommended for CI/CD):
   - Not an `Appfile` setting. Set `APP_STORE_CONNECT_API_KEY_PATH` to a
     [fastlane API key JSON file](https://docs.fastlane.tools/app-store-connect-api/) -
     `deliver` and `pilot` read it by themselves - or call
     `app_store_connect_api_key(key_id:, issuer_id:, key_filepath:)` in the
     Fastfile before uploading

2. **Apple ID Authentication** (for local use):
   - Set `apple_id` in `Appfile`
   - Fastlane will prompt for password/2FA

See [iOS Deployment Guide](../docs/deployment/ios-deployment.md) for setup instructions.

## 🌍 Environment Variables

Fastlane lanes support environment-specific builds:

```bash
# Android
fastlane android upload_production \
  environment:production \
  base_url:"$BASE_URL_PRODUCTION" \
  ssl_fingerprints:"$API_SSL_FINGERPRINTS"

# iOS
(cd ios && fastlane ios upload_appstore \
  environment:production \
  base_url:"$BASE_URL_PRODUCTION" \
  ssl_fingerprints:"$API_SSL_FINGERPRINTS")
```

Every build lane needs the API base URL: `base_url:<url>`, or
`BASE_URL_<ENVIRONMENT>` for the resolved `environment:` (trimmed and
lowercased), regardless of the lane name. Thus `environment:staging` reads
`BASE_URL_STAGING`, and `environment:production` reads `BASE_URL_PRODUCTION`.
An explicit `base_url:` always wins. Without one,
or with the starter's `example.com` placeholder, the lane stops before
building.

### Certificate pinning

Pinning is on in staging and production, and a release built with pinning on
and no fingerprints refuses to start. So every build lane (`build_bundle`,
`build_apk`, `build_appstore`, `build_adhoc`, and the upload lanes that call
them) needs one of:

- `ssl_fingerprints:<list>`, or the `API_SSL_FINGERPRINTS` environment
  variable: your server's SHA-256 fingerprints, comma-separated, colons
  optional. Each must be 64 hex digits.
- `ssl_pinning:false`, or `ENABLE_SSL_PINNING=false`: ship without pinning,
  on purpose.

With neither, a staging or production lane stops before it builds. The upload
lanes pass both options on to the build lane. The rules live in
[`ssl_pinning.rb`](ssl_pinning.rb), and match
[`scripts/ci/ssl_pinning_defines.sh`](../scripts/ci/ssl_pinning_defines.sh),
which the shell build paths use.

## 📝 Changelog

Android release notes live in
`fastlane/metadata/android/<locale>/changelogs/<version-code>.txt`, with
`default.txt` as the fallback when no version-specific file exists. The shipped
English fallback is `fastlane/metadata/android/en-US/changelogs/default.txt`.
Supply reads notes separately from listing metadata: the lanes' existing
`skip_upload_metadata: true` does not skip changelogs.

By default, iOS uploads use `skip_metadata: true` and do not read the Android notes.
Enter release notes in App Store Connect, or configure a separate iOS metadata
upload for your app.

This script updates the repository-root `CHANGELOG.md` for your app:
```bash
./scripts/ci/generate_changelog.sh 1.0.0
```
It does not populate either store's release notes. Adapt the content into the
Android locale files or App Store Connect separately.

## 🔗 Integration with CI/CD

Fastlane is integrated with GitHub Actions workflows:
- `.github/workflows/deploy-android.yml`
- `.github/workflows/deploy-ios.yml`

See [Deployment Documentation](../docs/deployment/) for CI/CD setup.

## 📚 Resources

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Android Deployment Guide](../docs/deployment/android-deployment.md)
- [iOS Deployment Guide](../docs/deployment/ios-deployment.md)
- [Deployment Summary](../docs/deployment/summary.md)

## 🐛 Troubleshooting

### Android Issues

**Error: "Could not find service account JSON"**
- Ensure `json_key_file` or `json_key_data_raw` is set in `Appfile`
- Or set `SUPPLY_JSON_KEY` / `SUPPLY_JSON_KEY_DATA` in the environment

**Error: "Package name mismatch"**
- Update `PACKAGE_NAME` in `Fastfile` to match your `applicationId`

### iOS Issues

**Error: "No team ID found"**
- Set `team_id` in `ios/fastlane/Appfile`
- Or set `FASTLANE_TEAM_ID` environment variable

**Error: "Could not find IPA"**
- The build/upload lanes run `flutter build ipa` themselves.
- Inspect their Flutter/Xcode export output under `build/ios/ipa/` and the path
  reported by the lane; resolve build/export errors before retrying the upload.

**Error: "Code signing failed"**
- Ensure Xcode signing is configured correctly
- Check that certificates and provisioning profiles are valid

## 💡 Tips

1. **Test locally first**: Always test builds locally before deploying
2. **Use staging environment**: Test with staging environment first
3. **Version management**: Use `./scripts/ci/bump_version.sh` to manage versions
4. **Changelog**: Keep changelog updated for each release
5. **CI/CD**: Use GitHub Actions for automated deployments


