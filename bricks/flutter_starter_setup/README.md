# flutter_starter_setup

Mason brick for this repository: renames the Dart package, Android `applicationId` / `namespace`, iOS bundle identifiers, Android app label, and relocates `MainActivity.kt`. Optionally runs `tool/strip_sample_features.dart` before renaming.

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

## Variables

| Variable | Purpose |
| --- | --- |
| `package_name` | `pubspec.yaml` `name` and `package:` imports |
| `application_id` | Android `namespace` + `applicationId` + Kotlin package |
| `ios_bundle_id` | Replaces `com.example.flutterStarter` in `project.pbxproj` |
| `app_display_name` | `android:label` in `AndroidManifest.xml` |
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
