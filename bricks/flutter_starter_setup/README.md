# flutter_starter_setup

Mason brick for this repository: renames the Dart package, Android `applicationId` / `namespace`, iOS and macOS bundle identifiers, the Android app label, the Patrol config, and the desktop/web/fastlane identifiers; relocates `MainActivity.kt` **and** the Patrol `MainActivityTest.java` that must share its package. Optionally runs `tool/strip_sample_features.dart` before renaming.

Parent index: [`../README.md`](../README.md).

## Prerequisites

- [Mason CLI](https://pub.dev/packages/mason_cli): `dart pub global activate mason_cli`
- Run from the **repository root** (where `pubspec.yaml` and `mason.yaml` live).

## Usage

```bash
mason get
mason make flutter_starter_setup
```

Answer the prompts. The brick adds a root-level `_mason_hook_only.md` (Mason requires a `__brick__` file); delete it after generation if you do not want it in the repo.

Then:

```bash
flutter pub get
flutter analyze
flutter test
```

## What gets rewritten

`hooks/post_gen.dart` replaces `package:flutter_starter/` → `package:<package_name>/` in **`.dart` files** under:

- `lib/`
- `test/`
- `integration_test/`
- `tool/`

It does **not** edit Markdown under `docs/` (code samples there may still say `flutter_starter` until you search/replace manually).

It also rewrites the template identifiers in these non-Dart files:

| File | What changes |
| --- | --- |
| `android/app/build.gradle.kts` | `namespace`, `applicationId` |
| `android/app/src/main/AndroidManifest.xml` | `android:label` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | moved + `package` |
| `android/app/src/androidTest/java/.../MainActivityTest.java` | moved + `package` - must stay in `MainActivity`'s package or the Patrol androidTest variant fails to compile |
| `pubspec.yaml` (`patrol:` block) | `app_name`, `android.package_name` - `patrol test` instruments this package |
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` (Runner + RunnerTests) |
| `ios/Runner/Info.plist` | `CFBundleDisplayName`, `CFBundleName` |
| `ios/ExportOptions.plist` | `provisioningProfiles` key |
| `macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME`, `PRODUCT_BUNDLE_IDENTIFIER`, `PRODUCT_COPYRIGHT` |
| `macos/Runner.xcodeproj/project.pbxproj` + `Runner.xcscheme` | bundle ids, `<name>.app` product references, `TEST_HOST` |
| `linux/CMakeLists.txt`, `linux/runner/my_application.cc` | `BINARY_NAME`, `APPLICATION_ID`, window title |
| `windows/CMakeLists.txt`, `windows/runner/Runner.rc`, `windows/runner/main.cpp` | project + binary name, version-resource strings, window title |
| `web/index.html`, `web/manifest.json` | page title, app name |
| `fastlane/Appfile`, `fastlane/Fastfile`, `ios/fastlane/Appfile`, `ios/fastlane/Fastfile` | `package_name`, `app_identifier`, `PACKAGE_NAME`, `APP_IDENTIFIER`, `APP_NAME` |

`com.example` on its own (the Windows `CompanyName` resource and the macOS
copyright line) becomes everything in `application_id` before its last segment.

## Variables

| Variable | Purpose |
| --- | --- |
| `package_name` | `pubspec.yaml` `name` and `package:` imports |
| `application_id` | Android `namespace` + `applicationId` + Kotlin package |
| `ios_bundle_id` | Replaces `com.example.flutterStarter` in the iOS and macOS `project.pbxproj`, `ios/ExportOptions.plist`, and both fastlane iOS configs |
| `app_display_name` | `android:label` in `AndroidManifest.xml`, `patrol.app_name`, and every `Flutter Starter` literal in the Apple/fastlane configs |
| `include_tasks_sample` | If false, removes the sample tasks (CRUD) module |
| `include_feature_flags_sample` | If false, removes the sample feature flags module |
| `strip_sample_features` | Legacy switch; if true, removes both tasks + feature_flags (see tool script) |

## Not using Mason

Use the manual steps in [Fork and customize](../../docs/guides/onboarding/fork-and-customize.md). Afterwards you may delete **`bricks/`** and **`mason.yaml`** if you want a slimmer tree.

## Developing this brick

After changing `hooks/post_gen.dart` or `hooks/pubspec.yaml`:

```bash
cd bricks/flutter_starter_setup/hooks
dart pub get
```

Keep `brick.yaml` → `environment.mason` compatible with the `mason` version in `hooks/pubspec.yaml`.

## Non-goals

- Does not switch Riverpod/BLoC or GoRouter to another framework.
- Does not configure Firebase or signing; use the security and fork docs for that.
