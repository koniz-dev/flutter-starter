# Fork and customize

Use this after you copy or fork the template into your own app.

## Minimal path (smallest useful fork)

1. Skim [Repository layout](repository-layout.md) to see which directories matter for your fork.
2. Remove optional sample modules if you do not need them:
   - Prefer Mason toggles when generating a new app.
   - Or run `dart run tool/strip_sample_features.dart --apply` (see section 3) to remove both **tasks** and **feature_flags** while keeping **auth** and core. <!-- strip:strip-tool line -->
3. Read [Choose your stack](../../architecture/choose-your-stack.md) to decide what to keep vs swap (network, storage, navigation adapters).
4. Follow sections 1 and 2 below to rename the package, display name and native ids.

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
   source).
4. Search `docs/` for `package:flutter_starter` in fenced code examples and update them if you care about copy-paste accuracy (the Mason brick does not rewrite Markdown).

**If you never use Mason:** after renaming, you can remove **`bricks/`** and **`mason.yaml`**.
Use `dart run tool/strip_sample_features.dart --apply --keep-samples --remove-bricks`, or add `--remove-bricks` to whichever strip you run: it also drops the passages in the docs that link into them, which deleting the two by hand leaves dangling. <!-- strip:strip-tool line -->

## 2. Display name and application ids

Option A sets all of these. With Option B, choose the values and run this from
the repository root once section 1 is done. It rewrites the same files the
setup brick does: the Dart-side name, every locale's strings, the Android,
iOS, macOS, Linux, Windows and web runners, the Patrol and fastlane configs,
and the ids FreeRASP checks the running app against - left at the template
values, a wired RASP flags your renamed app as repackaged.

```bash
export NAME='My App'                    # display name
export PACKAGE=my_app                   # the package name from section 1
export ANDROID_ID=com.mycompany.my_app  # Android namespace and applicationId
export APPLE_ID=com.mycompany.myApp     # iOS and macOS bundle identifier
export ORG="${ANDROID_ID%.*}"

# The display name and the template ids, everywhere outside docs/.
git grep -lz -e 'Flutter Starter' -e 'com\.example\.flutter' -- . \
  ':!docs' ':!bricks' ':!LICENSE' ':!.github/workflows/scripts-smoke.yml' \
  | xargs -0 perl -pi -e '
      s/com\.example\.flutterStarter/$ENV{APPLE_ID}/g;
      s/com\.example\.flutter_starter/$ENV{ANDROID_ID}/g;
      s/Flutter Starter/$ENV{NAME}/g'

# The launcher label and Patrol's app name are the display name; in the
# desktop and web runners the bare template name is the binary, window
# and page name.
perl -pi -e 's/android:label="flutter_starter"/android:label="$ENV{NAME}"/' \
  android/app/src/main/AndroidManifest.xml
perl -pi -e 's/^(  app_name:) flutter_starter$/$1 $ENV{NAME}/' pubspec.yaml
perl -pi -e 's/flutter_starter/$ENV{PACKAGE}/g; s/com\.example/$ENV{ORG}/g' \
  ios/Runner/Info.plist web/index.html web/manifest.json \
  linux/CMakeLists.txt linux/runner/my_application.cc \
  windows/CMakeLists.txt windows/runner/Runner.rc windows/runner/main.cpp \
  macos/Runner/Configs/AppInfo.xcconfig macos/Runner.xcodeproj/project.pbxproj \
  macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme

# MainActivity and the Patrol test runner live in a directory named after
# the Android id, and must stay in the same package.
for src in main/kotlin androidTest/java; do
  mkdir -p "android/app/src/$src/${ANDROID_ID//.//}"
  git mv android/app/src/$src/com/example/flutter_starter/* \
    "android/app/src/$src/${ANDROID_ID//.//}/"
done

flutter gen-l10n
```

Then check nothing is left, and that the app still builds and passes:

```bash
git grep -n -i -e 'flutter starter' -e 'com\.example\.flutter' -- . \
  ':!docs' ':!test' ':!bricks' ':!LICENSE' \
  ':!.github/workflows/scripts-smoke.yml'   # prints nothing
flutter analyze && flutter test
```

`LICENSE` keeps the template's copyright line, as its MIT terms require; add
your own above it. `scripts-smoke.yml` keeps the template name because its
rename jobs check that a rename *from* it worked; they mean nothing after
yours, so delete that workflow or leave it. The `welcome` string in each `lib/l10n/app_*.arb` now reads
"Welcome to My App with Clean Architecture!" - reword it as you like.

<!-- strip:strip-tool start -->
## 3. Strip sample features (optional)

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
does not rewrite prose.

The strip removes itself afterwards - the tool, its golden tree, its workflow
and its tests - since it cannot run twice; `--keep-samples` keeps it.
<!-- strip:strip-tool end -->

## 4. Remove auth sample (advanced)

There is no one-click script for removing `auth` (router redirects, DI, and tests are tightly coupled). If you drop auth:

- Rewrite `goRouterProvider` redirect rules in `lib/core/routing/app_router.dart`.
- Remove `lib/features/auth` (its providers live in `lib/features/auth/di/` and go with it), `buildAuthRoutes` in `lib/core/routing/routes_registry.dart`, and auth tests.
- Update `main.dart`: drop `authModuleOverrides`, and any storage or init that only served auth.

Use [contracts-map.md](../../architecture/contracts-map.md) to keep `ITokenStore` / `IKeyValueStore` if you still need tokens for APIs.

## 5. Entry documentation

- [Choose your stack](../../architecture/choose-your-stack.md) — Path A vs Path B.
- [Super starter hub](../../architecture/super-starter-hub.md) — full capability map.
- [Contracts and adapter map](../../architecture/contracts-map.md) — swap points.
