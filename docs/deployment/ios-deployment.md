# iOS deployment

## Goal

Archive an **IPA** and distribute via **App Store Connect** (TestFlight or App Store), locally or from CI.

## Prerequisites

- Bundle identifier and team id set for your fork ([Fork and customize](../guides/onboarding/fork-and-customize.md)).
- Apple Developer Program membership.
- Certificates and provisioning profiles (Xcode automatic signing locally, or match/certificates in CI).

## Native configuration checks

The checked-in iOS and macOS projects include Flutter's Swift Package Manager
integration. iOS uses the UIScene lifecycle, with plugin registration in
`didInitializeImplicitFlutterEngine`. Custom native lifecycle code should follow
the [Flutter UIScene migration guide](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate).

From the repository root on macOS with Xcode and CocoaPods installed:

```bash
flutter build ios --config-only --no-codesign
git status --short
flutter build macos --config-only
git status --short
```

Both configuration commands should complete without changing the checkout.
These checks resolve native dependencies and generate build configuration;
App Store distribution still follows the signing steps below. Review new
migrations when upgrading Flutter or Xcode.

Swift package resolutions are committed for
[iOS](../../ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
and [macOS](../../macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved).
Flutter's generated package under `Flutter/ephemeral` and CocoaPods output stay
ignored. The Podfiles, workspace references and CocoaPods configuration remain
available for plugins that need Flutter's
[CocoaPods fallback](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers).

## Steps

1. **Signing in Xcode** — Open `ios/Runner.xcworkspace`, set **Signing & Capabilities** for Release.
2. **App Store Connect API key** (recommended for CI) — Create an API key in App Store Connect; store key id, issuer id, and `.p8` path or secret in CI.
3. **Fastlane** — Follow the iOS sections in [`fastlane/README.md`](../../fastlane/README.md) (`APP_STORE_CONNECT_API_KEY_PATH` or `app_store_connect_api_key(key_id:, issuer_id:, key_filepath:)`, or the Apple ID flow for local use).
4. **CI** — Edit [`.github/workflows/deploy-ios.yml`](../../.github/workflows/deploy-ios.yml): add secrets and enable triggers when ready.

## References

- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)
- [Fastlane iOS beta / deliver](https://docs.fastlane.tools/getting-started/ios/beta-deployment/)
