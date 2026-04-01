# Fork and customize

Use this after you copy or fork the template into your own app.

## Minimal path (smallest useful fork)

1. Skim [Repository layout](repository-layout.md) to see which directories matter for your fork.
2. Remove optional sample modules if you do not need them:
   - Prefer Mason toggles when generating a new app.
   - Or run `dart run tool/strip_sample_features.dart --apply` (see section 4) to remove both **tasks** and **feature_flags** while keeping **auth** and core.
3. Read [Choose your stack](../../architecture/choose-your-stack.md) to decide what to keep vs swap (network, storage, navigation adapters).
4. Follow sections 1–3 below to rename the package and native ids.

## 1. Rename the Dart package

The published package name is `flutter_starter`. Pick a **snake_case** name (e.g. `my_awesome_app`).

**Option A — Mason (recommended)**

From the repository root (with [Mason CLI](https://pub.dev/packages/mason_cli) installed):

```bash
dart pub global activate mason_cli
mason get
mason make flutter_starter_setup
```

Answer the prompts for `package_name`, Android `application_id`, iOS `bundle_identifier`, `app_display_name`, and whether to include optional samples (`tasks`, `feature_flags`).

**Option B — Manual**

1. Change `name:` in `pubspec.yaml`.
2. Replace every import `package:flutter_starter/` with `package:<your_package>/` under `lib/`, `test/`, `integration_test/`, and `tool/` (Dart files).
3. Run `flutter pub get` and fix any missed imports.
4. Search `docs/` for `package:flutter_starter` in fenced code examples and update them if you care about copy-paste accuracy (the Mason brick does not rewrite Markdown).

**If you never use Mason:** after renaming, you may delete **`bricks/`** and **`mason.yaml`** to keep a smaller repo.

## 2. Android application id and namespace

After Mason, `android/app/build.gradle.kts` should already use your `application_id` and matching `namespace`.

If you do it manually:

- Set `namespace` and `applicationId` in `android/app/build.gradle.kts`.
- Move `MainActivity.kt` to `android/app/src/main/kotlin/<your/path>/MainActivity.kt` and set `package ...` to match `namespace`.
- Set `android:label` in `AndroidManifest.xml` if needed.

## 3. iOS bundle identifier

- Set `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` (Runner + RunnerTests targets).

## 4. Strip sample features (optional)

Removing **`tasks`** and **`feature_flags`** gives a smaller tree while keeping **`auth`** and core infrastructure.

- **With Mason:** set `include_tasks_sample` and/or `include_feature_flags_sample` to `false` when running `mason make flutter_starter_setup`.
- **Without Mason:** from repo root:

```bash
dart run tool/strip_sample_features.dart --apply
flutter pub get
flutter analyze
flutter test
```

Targeted variants:

```bash
# Remove tasks only (keep feature flags)
dart run tool/strip_sample_features.dart --apply --tasks-only

# Remove feature_flags only (keep tasks)
dart run tool/strip_sample_features.dart --apply --feature-flags-only
```

Then delete or adjust any remaining docs under `docs/features/` that referenced removed modules.

## 5. Remove auth sample (advanced)

There is no one-click script for removing `auth` (router redirects, DI, and tests are tightly coupled). If you drop auth:

- Rewrite `goRouterProvider` redirect rules in `lib/core/routing/app_router.dart`.
- Remove `lib/features/auth`, related providers in `lib/core/di/providers.dart`, and auth tests.
- Update `main.dart` if you remove storage or init that only served auth.

Use [contracts-map.md](../../architecture/contracts-map.md) to keep `ITokenStore` / `IKeyValueStore` if you still need tokens for APIs.

## 6. Entry documentation

- [Choose your stack](../../architecture/choose-your-stack.md) — Path A vs Path B.
- [Super starter hub](../../architecture/super-starter-hub.md) — full capability map.
- [Contracts and adapter map](../../architecture/contracts-map.md) — swap points.
