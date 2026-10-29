# Android deployment

## Goal

Produce a signed **App Bundle** and upload to **Google Play** (internal, beta, or production), either locally via Fastlane or via GitHub Actions.

## Prerequisites

- Application id / namespace aligned with your fork ([Fork and customize](../guides/onboarding/fork-and-customize.md)).
- Release keystore and Play Console access.
- **Google Play service account** JSON for API upload (CI) or local Fastlane auth.

## Release signing

`android/app/build.gradle.kts` reads its release signing config from
`android/key.properties`. Without that file, **a release build is refused** -
`flutter build apk --release` and `flutter build appbundle` stop with
"Release signing is not configured ... Refusing." - rather than producing an
unsigned or debug-signed artifact. Debug builds, `flutter run`,
`flutter analyze` and `flutter test` are unaffected.

Generate an upload keystore once, outside version control:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (both files are git-ignored):

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

`storeFile` is relative to `android/`, or absolute. A `.properties` file has
no trailing comments - text after a value, `#` included, becomes part of it -
so put any note on a line of its own that starts with `#`.

In CI, [`deploy-android.yml`](../../.github/workflows/deploy-android.yml)
ships a commented-out "Setup Android keystore" step that writes both from
secrets; uncomment it once the secrets exist.

To check that a release build compiles before you have a keystore, build an
**unsigned** release for a local smoke test:

```bash
flutter build apk --release --dart-define-from-file=.env -PallowUnsignedRelease=true
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`. It is not
signed, so it **cannot be installed on a device or uploaded** to Google Play;
it only proves the release build compiles.

## Steps

1. **Signing** — Set up `android/key.properties` and the keystore as in [Release signing](#release-signing); do not commit either. In CI, keep them in secrets.
2. **Play API access** — In Play Console, link a Google Cloud project and create a service account with release permissions; download the JSON key.
3. **Fastlane** — Follow the Android sections in [`fastlane/README.md`](../../fastlane/README.md) (`json_key_file` or `json_key_data_raw` in the Appfile, or `SUPPLY_JSON_KEY` / `SUPPLY_JSON_KEY_DATA`).
4. **CI** — Edit [`.github/workflows/deploy-android.yml`](../../.github/workflows/deploy-android.yml): add secrets (signing + Play JSON), then enable triggers when you are ready.

## References

- [Flutter Android deployment](https://docs.flutter.dev/deployment/android)
- [Fastlane supply](https://docs.fastlane.tools/actions/supply/)
