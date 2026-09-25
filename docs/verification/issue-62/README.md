# Acceptance evidence for issue #62

Fix merged as PR #132 (`dbee1c6`). Gate logs (`format.log`, `analyze.log`,
`tests.log`) are from `./scripts/test/run_acceptance.sh 62 --no-goldens` run on
`main` after the merge.

`--no-goldens` on purpose: the diff touches nothing under `lib/`, so the six
standing goldens `run_acceptance.sh` would otherwise copy in could only be
miscited. **There are no PNGs in this directory** and no criterion below rests on
a screenshot.

## Verdict per criterion

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | `flutter run -d macos` reaches the network; both entitlements grant `com.apple.security.network.client` | PASS | `criterion-1-macos-release-app-entitlements.txt` |
| 2 | Secure storage persists across restart on macOS and iOS; `keychain-access-groups` on both; iOS entitlements file wired | **PARTIAL -> needs-uat** | `criterion-2-macos-keychain-probe-without-entitlement.log`, `criterion-2-macos-keychain-entitlement-breaks-unsigned-build.log` |
| 3 | Release build signed with a release key when `key.properties` is present; fails loudly when absent | PASS | `criterion-3-android-release-signing.md` |
| 4 | Every fastlane lane runs to the credential wall; no `--flavor`; paths resolve; `base_url` escaped; `skip_screenshots` honoured; `build_adhoc` is ad-hoc | **PARTIAL -> needs-uat** | `criterion-4-fastlane-lanes.log`, `criterion-4-fastlane-static-checks.md` |
| 5 | `ios/ExportOptions.plist` uses the real bundle ID | PASS | `criteria-5-10-11-static.md` |
| 6 | After `mason make`, the identifier grep returns only intentional matches, and the Patrol androidTest harness still compiles | **PARTIAL -> needs-uat** | `criterion-6-mason-rename-grep.log` |
| 7 | `setup_branding.sh` succeeds on a fresh clone or fails accurately | PASS | `criterion-7-setup-branding-fresh-clone.log` |
| 8 | `assets/images/` and `assets/config/` declared in `pubspec.yaml` | PASS | `criterion-8-assets-bundled.md` |
| 9 | Roboto bundled, or `fontFamily` dropped | **NOT DONE - split to #143** | see below |
| 10 | iOS and macOS deployment targets match the pinned Flutter | PASS | `criteria-5-10-11-static.md` |
| 11 | Podfiles committed or gitignored; signing material gitignored | PASS | `criteria-5-10-11-static.md` |
| 12 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `format.log`, `analyze.log`, `tests.log` |

## What was executed versus read

Executed, output captured in this directory:

- `flutter build macos --release` twice, and `codesign -d --entitlements -` on
  the resulting `.app`.
- `flutter build ios --no-codesign` (succeeds with the new
  `CODE_SIGN_ENTITLEMENTS`).
- `flutter test -d macos` against a temporary `FlutterSecureStorage` probe, with
  and without the keychain entitlement.
- `flutter build web --release`, then decoding `AssetManifest.bin.json`.
- `mason make flutter_starter_setup` against a full copy of this branch, then
  grepping the generated project.
- Six fastlane lanes on both platforms, fastlane 2.240.1.
- `./scripts/dev/setup_branding.sh` on the shipped tree.
- Two dispatched CI runs (36134640833, 36135666505), and the release APK
  downloaded and its signer certificate extracted.
- `./scripts/dev/audit_template.sh` and `run_acceptance.sh 62 --no-goldens`.

Read, not executed: nothing is claimed on that basis. Where a thing could not be
run at all, it is routed to `needs-uat` below rather than asserted.

## Routed to a human

**Criterion 2 - macOS keychain.** Measured both ways. The entitlement is
genuinely required (`-34018` without it) and it is a *restricted* entitlement:
with it present, `flutter build macos` and `flutter run -d macos` fail on any
machine with no Apple development certificate (`security find-identity -v -p
codesigning` here: `0 valid identities found`). It therefore ships commented out
in both `macos/Runner/*.entitlements`, with the tradeoff written next to it. The
iOS half **is** shipped and builds.

To finish it, a human with a certificate: uncomment the `keychain-access-groups`
block in both macOS entitlements files, `flutter run -d macos`, log in, quit,
relaunch. PASS = still logged in. Same on an iOS device for the iOS half.

**Criterion 4 - build and upload lanes.** The six lanes that need no credentials
run green. `build_bundle`, `build_apk`, `build_appstore`, `build_adhoc` and every
`upload_*` lane need an Android SDK / Xcode signing identity / App Store Connect
or Play credentials. PASS = each reaches the credential prompt or the platform
build, rather than dying on a flavor or an unreadable path.

**Criterion 6 - androidTest compile.** The package parity that makes the compile
possible is shown in the log. Actually compiling the renamed androidTest variant
needs a JDK and an Android SDK. PASS = after `mason make` with a custom
application id, `./gradlew :app:assembleDebugAndroidTest` succeeds, or
`patrol test` reports `Total: >= 1`.

**Criterion 9 - `AppTypography.fontFamily`.** Not attempted here on purpose:
`lib/shared/design_system/tokens/app_typography.dart` is `epic:design-system`,
which had another implementer active (#65) for the whole of this work. Filed as a
separate issue rather than risking a conflicting edit in someone else's slice:
koniz-dev/flutter-starter#143.
