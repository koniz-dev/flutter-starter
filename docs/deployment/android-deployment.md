# Android deployment

## Goal

Produce a signed **App Bundle** and upload to **Google Play** (internal, beta, or production), either locally via Fastlane or via GitHub Actions.

## Prerequisites

- Application id / namespace aligned with your fork ([Fork and customize](../guides/onboarding/fork-and-customize.md)).
- Release keystore and Play Console access.
- **Google Play service account** JSON for API upload (CI) or local Fastlane auth.

## Steps

1. **Signing** — Configure `android/app/build.gradle.kts` (or Groovy) with your release signing config; do not commit keystore passwords. Use CI secrets for `key.properties` or env-injected values.
2. **Play API access** — In Play Console, link a Google Cloud project and create a service account with release permissions; download the JSON key.
3. **Fastlane** — Follow the Android sections in [`fastlane/README.md`](../../fastlane/README.md) (`json_key_file`, `json_key_data`, or `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`).
4. **CI** — Edit [`.github/workflows/deploy-android.yml`](../../.github/workflows/deploy-android.yml): add secrets (signing + Play JSON), then enable triggers when you are ready.

## References

- [Flutter Android deployment](https://docs.flutter.dev/deployment/android)
- [Fastlane supply](https://docs.fastlane.tools/actions/supply/)
