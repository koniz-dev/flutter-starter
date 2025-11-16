# iOS Deployment Guide

Complete guide for deploying Flutter Starter to Apple App Store.

## Prerequisites

- Apple Developer account ($99/year)
- macOS with Xcode installed
- Flutter SDK installed
- CocoaPods installed (`sudo gem install cocoapods`)

## Step 1: Apple Developer Account Setup

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Sign in with your Apple ID
3. Enroll in Apple Developer Program ($99/year)
4. Complete enrollment process

## Step 2: Create App ID

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Click "+" to create new identifier
3. Select "App IDs" → Continue
4. Select "App" → Continue
5. Fill in:
   - **Description**: Your app name
   - **Bundle ID**: `com.example.flutter_starter` (must match your app)
6. Select capabilities (Push Notifications, In-App Purchase, etc.)
7. Register

## Step 3: Configure Xcode Project

### Update Bundle Identifier

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. General tab → Bundle Identifier
4. Set to your App ID: `com.example.flutter_starter`

### Configure Signing

1. In Xcode, select Runner target
2. Go to "Signing & Capabilities" tab
3. Enable "Automatically manage signing"
4. Select your Team
5. Xcode will automatically:
   - Create provisioning profiles
   - Manage certificates
   - Handle signing

### Manual Signing (Optional)

If you prefer manual signing:

1. Disable "Automatically manage signing"
2. Select provisioning profile for each configuration:
   - **Debug**: Development profile
   - **Release**: App Store profile
3. Select signing certificate

## Step 4: Create Provisioning Profiles

### Automatic (Recommended)

Xcode automatically creates profiles when "Automatically manage signing" is enabled.

### Manual Creation

1. Go to [Provisioning Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Click "+" to create new profile
3. Select profile type:
   - **Development**: For development builds
   - **App Store**: For App Store distribution
   - **Ad Hoc**: For internal testing
4. Select your App ID
5. Select certificates
6. Select devices (for Development/Ad Hoc)
7. Name the profile
8. Download and install

## Step 5: Configure Info.plist

Update `ios/Runner/Info.plist`:

```xml
<key>CFBundleDisplayName</key>
<string>Flutter Starter</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleVersion</key>
<string>$(FLUTTER_BUILD_NUMBER)</string>
<key>CFBundleShortVersionString</key>
<string>$(FLUTTER_BUILD_NAME)</string>
<key>LSRequiresIPhoneOS</key>
<true/>
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
<key>UIMainStoryboardFile</key>
<string>Main</string>
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>armv7</string>
</array>
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

## Step 6: Build IPA

### Using Flutter CLI

```bash
flutter build ipa \
  --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BASE_URL=https://api.example.com
```

Output: `build/ios/ipa/Runner.ipa`

### Using Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Wait for archive to complete
5. Window → Organizer
6. Select archive → Distribute App
7. Choose distribution method:
   - **App Store Connect**: For App Store
   - **Ad Hoc**: For internal testing
   - **Enterprise**: For enterprise distribution
   - **Development**: For development builds

## Step 7: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - **Platform**: iOS
   - **Name**: Your app name
   - **Primary Language**: English (or your language)
   - **Bundle ID**: Select your App ID
   - **SKU**: Unique identifier (e.g., `flutter-starter-001`)
4. Create app

## Step 8: Prepare Store Listing

### Required Information

1. **App Information**:
   - Category: Primary and secondary
   - Subtitle: 30 characters max
   - Privacy Policy URL: Required

2. **Pricing and Availability**:
   - Price: Free or paid
   - Availability: Countries/regions

3. **App Privacy**:
   - Complete privacy questionnaire
   - Describe data collection practices

### Required Assets

1. **App Icon**: 1024x1024px PNG (no transparency, no rounded corners)
2. **Screenshots**:
   - iPhone 6.7" Display: 1290x2796px (required)
   - iPhone 6.5" Display: 1284x2778px
   - iPhone 5.5" Display: 1242x2208px
   - iPad Pro 12.9": 2048x2732px
   - At least 3 screenshots per device size
3. **App Preview Video**: Optional but recommended
4. **Description**: 
   - Name: 30 characters max
   - Subtitle: 30 characters max
   - Description: Up to 4000 characters
   - Keywords: 100 characters max (comma-separated)
   - Promotional Text: 170 characters max

### App Review Information

1. **Contact Information**:
   - First name, last name
   - Phone number
   - Email address

2. **Demo Account** (if required):
   - Username and password
   - Notes for reviewer

3. **Notes**:
   - Additional information for reviewers
   - Test account credentials
   - Special setup instructions

## Step 9: Upload to App Store Connect

### Using Xcode

1. Archive your app in Xcode
2. Window → Organizer
3. Select archive → Distribute App
4. Choose "App Store Connect"
5. Select distribution options:
   - Upload your app's symbols
   - Manage Version and Build Number
6. Review and upload
7. Wait for processing (10-30 minutes)

### Using Transporter

1. Download [Transporter](https://apps.apple.com/us/app/transporter/id1450874784)
2. Open Transporter
3. Drag and drop your `.ipa` file
4. Sign in with your Apple ID
5. Deliver

### Using Command Line (fastlane)

See [CI/CD workflows](../deployment.md#cicd-pipeline) for automated upload.

## Step 10: Submit for Review

1. Go to App Store Connect → Your App
2. Select the build you uploaded
3. Fill in all required information:
   - App Information
   - Pricing and Availability
   - App Privacy
   - Version Information
4. Click "Submit for Review"
5. Wait for review (typically 24-48 hours)

### Review Status

- **Waiting for Review**: In queue
- **In Review**: Being reviewed
- **Pending Developer Release**: Approved, waiting for release
- **Ready for Sale**: Available on App Store
- **Rejected**: Needs fixes (check Resolution Center)

## Step 11: TestFlight (Beta Testing)

### Internal Testing

1. Upload build to App Store Connect
2. Go to TestFlight tab
3. Add internal testers (up to 100)
4. Testers receive email invitation
5. Install TestFlight app to test

### External Testing

1. Upload build to App Store Connect
2. Create external test group
3. Add testers (up to 10,000)
4. Submit for Beta App Review (required for external testing)
5. Once approved, testers can install via TestFlight

## Step 12: Release Management

### Automatic Release

- App automatically releases when approved

### Manual Release

1. After approval, go to App Store Connect
2. Click "Release This Version"
3. App goes live immediately

### Phased Release

1. Enable "Phased Release" in version information
2. Release to 1% of users initially
3. Gradually increase to 100% over 7 days
4. Monitor for issues
5. Can pause or halt release if issues found

## Step 13: Post-Release Monitoring

### App Store Connect Metrics

1. **Sales and Trends**: Downloads, revenue
2. **App Analytics**: User engagement, retention
3. **Crash Reports**: Monitor crashes and ANRs
4. **Reviews and Ratings**: Respond to user feedback

### Update Process

1. Make changes to your app
2. Increment version in `pubspec.yaml`
3. Build new IPA
4. Upload to App Store Connect
5. Update version information
6. Submit for review

## Troubleshooting

### Build Errors

**"No signing certificate found"**:
- Check Xcode → Preferences → Accounts
- Download certificates
- Ensure team is selected

**"Provisioning profile not found"**:
- Enable "Automatically manage signing" in Xcode
- Or manually download and install profile

**"Code signing error"**:
- Verify bundle identifier matches App ID
- Check signing certificate is valid
- Ensure provisioning profile includes your device (for development)

### Upload Errors

**"Invalid bundle"**:
- Check bundle identifier
- Verify version number is incremented
- Ensure all required assets are included

**"Processing failed"**:
- Check email for specific error
- Verify app doesn't use private APIs
- Check for missing required icons

### App Store Connect Issues

**"App rejected"**:
- Check Resolution Center for specific reason
- Address all issues
- Resubmit after fixes

**"Build processing failed"**:
- Check build logs in App Store Connect
- Verify all frameworks are included
- Check for missing dependencies

## Best Practices

1. **Test on real devices**: Use TestFlight for beta testing
2. **Follow App Store Guidelines**: Review [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
3. **Regular updates**: Keep app updated with bug fixes
4. **Monitor reviews**: Respond to user feedback
5. **Privacy compliance**: Complete privacy questionnaire accurately
6. **Version management**: Always increment build number

## Resources

- [App Store Connect](https://appstoreconnect.apple.com)
- [Apple Developer Portal](https://developer.apple.com/account)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)

