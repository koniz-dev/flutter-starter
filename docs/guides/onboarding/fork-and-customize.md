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
2. Replace every `package:flutter_starter/` with `package:<your_package>/` in
   all of these - not only `lib/`, `test/`, `integration_test/` and `tool/`:
   - `examples/` - `flutter analyze` covers it, so a missed file keeps analyze
     red after the rename.
   - `scripts/dev/create_feature.sh` and `scripts/dev/create_feature.ps1` -
     they write the import lines of every feature you scaffold, so a missed
     script produces features that do not compile.
   - `bricks/feature_clean/__brick__/` - the same, for `mason make feature_clean`.

   One command for all of them (`perl` behaves the same on macOS and Linux):

   ```bash
   NEW=your_package
   git grep -lz 'package:flutter_starter/' -- lib test integration_test tool \
     examples bricks/feature_clean scripts/dev/create_feature.sh \
     scripts/dev/create_feature.ps1 'docs/*.dart' \
     | xargs -0 perl -pi -e "s#package:flutter_starter/#package:${NEW}/#g"
   ```
3. Run `flutter pub get`, then re-sort the imports - your package name sorts
   differently from `flutter_starter`, so roughly 200 files gain a
   `directives_ordering` info - and analyze:

   ```bash
   flutter pub get
   dart fix --apply --code=directives_ordering
   flutter analyze   # must exit 0
   ```

   Finish step 2 completely first. If any `package:flutter_starter/` import is
   left, `dart fix` also applies `depend_on_referenced_packages` and adds
   `flutter_starter: any` to `pubspec.yaml` - an unrelated pub.dev package -
   after which `flutter pub get` fails version solving.

   `git grep -n 'package:flutter_starter/' -- '*.dart' '*.sh' '*.ps1'` should
   then list only `bricks/flutter_starter_setup/` (the setup brick's own rename
   source - remove it with `--remove-bricks`, below, if you never use Mason).
4. Search `docs/` for `package:flutter_starter` in fenced code examples and update them if you care about copy-paste accuracy (the Mason brick does not rewrite Markdown).

**If you never use Mason:** after renaming, remove **`bricks/`** and **`mason.yaml`** with `dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks`, or add `--remove-bricks` to whichever strip you run. It also drops the passages in the docs that link into them; deleting the two by hand leaves those links dangling and fails the Docs check (koniz-dev/flutter-starter#588).

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

Naming both samples is the same request as naming neither, so
`--apply --tasks-only --feature-flags-only` behaves exactly like a bare `--apply`.

To keep **both** samples and only drop the Mason bricks, use:

```bash
dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks
```

All four variants are exercised by [`strip-smoke.yml`](../../../.github/workflows/strip-smoke.yml), which applies each one and then runs `flutter analyze` and `flutter test` over the result.

Then search the kept guides for the removed modules (for example
`git grep -n -i "feature.flag" docs/guides`) and adjust what you find; the strip
does not rewrite prose (koniz-dev/flutter-starter#409).

## 5. Remove auth sample (advanced)

There is no one-click script for removing `auth` (router redirects, DI, and tests are tightly coupled). If you drop auth:

- Rewrite `goRouterProvider` redirect rules in `lib/core/routing/app_router.dart`.
- Remove `lib/features/auth` (its providers live in `lib/features/auth/di/` and go with it), `buildAuthRoutes` in `lib/core/routing/routes_registry.dart`, and auth tests.
- Update `main.dart`: drop `authModuleOverrides`, and any storage or init that only served auth.

Use [contracts-map.md](../../architecture/contracts-map.md) to keep `ITokenStore` / `IKeyValueStore` if you still need tokens for APIs.

## 6. Entry documentation

- [Choose your stack](../../architecture/choose-your-stack.md) — Path A vs Path B.
- [Super starter hub](../../architecture/super-starter-hub.md) — full capability map.
- [Contracts and adapter map](../../architecture/contracts-map.md) — swap points.
