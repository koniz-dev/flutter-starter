# iOS deployment

## Goal

Archive an **IPA** and distribute via **App Store Connect** (TestFlight or App Store), locally or from CI.

## Prerequisites

- Bundle identifier and team id set for your fork ([Fork and customize](../guides/onboarding/fork-and-customize.md)).
- Apple Developer Program membership.
- Certificates and provisioning profiles (Xcode automatic signing locally, or match/certificates in CI).

## Steps

1. **Signing in Xcode** — Open `ios/Runner.xcworkspace`, set **Signing & Capabilities** for Release.
2. **App Store Connect API key** (recommended for CI) — Create an API key in App Store Connect; store key id, issuer id, and `.p8` path or secret in CI.
3. **Fastlane** — Follow the iOS sections in [`fastlane/README.md`](../../fastlane/README.md) (`api_key_path`, `api_key_id`, `issuer_id`, or Apple ID flow for local use).
4. **CI** — Edit [`.github/workflows/deploy-ios.yml`](../../.github/workflows/deploy-ios.yml): add secrets and enable triggers when ready.

## References

- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)
- [Fastlane iOS beta / deliver](https://docs.fastlane.tools/getting-started/ios/beta-deployment/)
