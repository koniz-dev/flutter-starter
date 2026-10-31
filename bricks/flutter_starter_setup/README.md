# flutter_starter_setup

Mason brick for this repository: renames the Dart package, Android `applicationId` / `namespace`, iOS and macOS bundle identifiers, the Android app label, the Patrol config, and the desktop/web/fastlane identifiers; relocates `MainActivity.kt` **and** the Patrol `MainActivityTest.java` that must share its package. Optionally runs `tool/strip_sample_features.dart` before renaming.

Parent index: [`../README.md`](../README.md).

## Prerequisites

- [Mason CLI](https://pub.dev/packages/mason_cli): `dart pub global activate mason_cli`, with `~/.pub-cache/bin` on `PATH` (`export PATH="$PATH":"$HOME/.pub-cache/bin"`). Without it `mason` is `command not found`; see [Fork and customize](../../docs/guides/onboarding/fork-and-customize.md).
- Run from the **repository root** (where `pubspec.yaml` and `mason.yaml` live).

## Usage

```bash
mason get
mason make flutter_starter_setup
```

Answer the prompts. The brick adds a root-level `_mason_hook_only.md` (Mason requires a `__brick__` file); delete it after generation if you do not want it in the repo.

The hook finishes with `flutter pub get`, `flutter gen-l10n`,
`dart fix --apply --code=directives_ordering` and `dart format` (see
"Repairing what the rename breaks" below), so the next step is just:

```bash
flutter analyze
flutter test
```

Both should be as clean on the renamed tree as they were before. If
`flutter analyze` reports anything the template did not, that is a bug in this
brick.

## What gets rewritten

`hooks/post_gen.dart` replaces `package:flutter_starter/` → `package:<package_name>/` in **`.dart` and `.dart.template` files** under:

- `lib/`
- `test/`
- `integration_test/`
- `tool/`
- `examples/`
- `docs/` - only `.dart` files, such as committed verification probes. The analyzer reads them, because `analysis_options.yaml` does not exclude `docs/`.

It rewrites `package:flutter_starter/` in the root `README.md` and `CONTRIBUTING.md`, whose code samples a team copies, but does **not** edit Markdown under `docs/` (code samples there may still say `flutter_starter` until you search/replace manually).

### Repairing what the rename breaks

A string replace of the package name leaves every import block where it was.
`package:flutter_starter/` happened to sort between `flutter_riverpod` and
`flutter_test`, and almost any other name does not, so `very_good_analysis`'s
`directives_ordering` used to fire on about 175 files after a rename - and
`.githooks/pre-commit` runs `flutter analyze`, so the rename could not even be
committed. The hook therefore runs, in the repository root:

1. `flutter pub get` - resolves the renamed package;
2. `flutter gen-l10n` - rebuilds `lib/l10n/app_localizations*.dart` from the
   updated ARB files;
3. `dart fix --apply --code=directives_ordering .` - re-sorts exactly the
   import blocks the rename disturbed, and applies no other fix;
4. `dart format` over the same directories.

### The display name on the Dart side

`app_display_name` replaces the exact template name, never a sentence that
mentions it:

| File | What changes |
| --- | --- |
| `lib/main.dart` | `MaterialApp(title:)` |
| `lib/core/startup/startup_failure_app.dart` | `MaterialApp(title:)` |
| `lib/core/constants/app_constants.dart` | `AppConstants.appName` |
| `lib/l10n/app_*.arb` | `appTitle` in every locale, then regenerated |
| `test/`, `integration_test/` | the whole-string `'Flutter Starter'` literals that assert the above |

The `welcome` sentence ("Welcome to Flutter Starter with Clean
Architecture!") is left as it is in each locale; reword it yourself.

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
| `app_display_name` | `android:label` in `AndroidManifest.xml`, `patrol.app_name`, every `Flutter Starter` literal in the Apple/fastlane configs, and the Dart-side name listed above. Each is escaped for its file (XML entities, a quoted YAML string, a Ruby string), so `Salt & Pepper` is safe; a blank name, a line break or other control character, `{` or `}` (ICU syntax in the localizations) and a leading `@` or `?` (an Android resource reference) are refused before anything changes |
| `include_tasks_sample` | If false, removes the sample tasks (CRUD) module |
| `include_feature_flags_sample` | If false, removes the sample feature flags module |
| `strip_sample_features` | Legacy switch; if true, removes both tasks + feature_flags (see tool script) |

## Not using Mason

Use the manual steps in [Fork and customize](../../docs/guides/onboarding/fork-and-customize.md). Afterwards you may remove **`bricks/`** and **`mason.yaml`** if you want a slimmer tree.
Use `dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks`; deleting them by hand leaves links to them dangling in the docs. <!-- strip:strip-tool line -->

## Developing this brick

CI cover: the `setup-brick` job of
[`scripts-smoke.yml`](../../.github/workflows/scripts-smoke.yml) runs this brick
with non-default answers and then `flutter analyze` and `flutter test`. It is
manual, like the rest of that workflow. Run it after touching the hook.

Invalid input is refused before anything is written: `hooks/pre_gen.dart`
checks `package_name` (a pub name, not a Dart reserved word),
`application_id` (two or more segments of letters, digits and underscores),
`ios_bundle_id` (letters, digits and hyphens) and `app_display_name` (see the
table above) through `hooks/input_rules.dart`.

After changing any file under `hooks/` (`pre_gen.dart`, `post_gen.dart`,
`input_rules.dart` or `pubspec.yaml`):

```bash
cd bricks/flutter_starter_setup/hooks
dart pub get
```

Keep `brick.yaml` → `environment.mason` compatible with the `mason` version in `hooks/pubspec.yaml`.

## Non-goals

- Does not switch Riverpod/BLoC or GoRouter to another framework.
- Does not configure Firebase or signing; use the security and fork docs for that.
