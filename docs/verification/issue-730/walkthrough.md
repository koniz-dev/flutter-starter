# Adopter walkthrough from a clean clone (koniz-dev/flutter-starter#730)

- Date: 2026-10-28, 22:31 - 23:25 local
- Source: `git clone https://github.com/koniz-dev/flutter-starter.git /Users/nguyenanhkiet/Playground/fs-walkthrough`, `main` at `50ad5f4` ("fix(ci): match workflow and action file names case-insensitively (#752)")
- Toolchain: Flutter 3.47.0 stable (Dart 3.13.0), Android SDK 36, Xcode, Chrome, macOS 15 (Darwin 24.6.0). No device.
- App name used: `acme_notes` / "Acme Notes" / `com.acme.acme_notes` / `com.acme.acmeNotes`. Real API: https://dummyjson.com
- Nothing was committed or pushed from the clone; `main` is untouched. Every command ran from the clone root through a wrapper that appends the command, its start time, its exit code and its elapsed seconds to the `.log` files next to this one.
- Docs read, in order: `README.md`, `docs/guides/onboarding/getting-started.md`, `docs/guides/onboarding/fork-and-customize.md`, `bricks/README.md`, `bricks/flutter_starter_setup/README.md`, `tool/README.md`, `docs/architecture/choose-your-stack.md`, `docs/guides/configuration.md`, `docs/api/features/auth/models.md`, `docs/api/examples/adding-features.md`, `docs/guides/features/routing-guide.md`, `docs/guides/features/common-tasks.md`, `docs/deployment/android-deployment.md`.

Line numbers in the friction notes refer to `main` at `50ad5f4`. The strip rewrites some docs, so in the stripped clone some of them have shifted.

## Summary

| Step | Result | Wall clock | Friction (issue) |
|---|---|---|---|
| 0. Clone, `flutter pub get`, hooks | pass | ~1 min | getting-started `cd flutter_starter` (#766), build_runner shown as a setup step (#767) |
| 1. Rename with the Mason brick | pass | ~2 min rename + ~10 min analyze/test | `mason` not on PATH after activation (#769) |
| 2. Strip both samples | **fail, worked around**: 1 test red | ~11 min (9 of them `flutter test`) | strip after Mason rename reverts the app title (#759); routing guide left on removed `AppRoutes.tasks` (#770) |
| 3. `BASE_URL` at a real API | **gap recorded, sign-in not made to work** | ~6 min | contract not linked from onboarding (#760); silent `/v1` prefix (#761); no adaptation guide (#762) |
| 4. `create_feature.sh` + one routed screen | pass after a workaround | ~12 min + test rerun | feature guide ignores the scaffold and has no routing step (#763); hidden "home last" order in the registry test (#764); common-tasks contradicts routing-guide (#771) |
| 5. Release APK + web build | web **pass**; APK **not built** (host disk full, then a broken NDK directory the session was not allowed to delete) | ~7 min | release-signing refusal and unsigned flag only in the Gradle error (#765) |

Duplicates checked with `gh issue list --state all --search ...` before filing: the closest existing issues were #283 (brick never applied the display name to the Dart side - fixed for `lib/`, not for `tool/golden`), #627 (strip after rename and import order), #489 (wire format documented - it is, just not linked from onboarding), #312 and #306 (auth casing and the int id `TypeError` in Result handling), #356 (feature providers in core DI). None covers the findings below, so nothing was linked as a duplicate. Each one was filed separately.

## Step 0 - clone and README "Getting started"

| Command | Exit | Elapsed | Log |
|---|---|---|---|
| `git clone https://github.com/koniz-dev/flutter-starter.git fs-walkthrough` | 0 | 7s | - |
| `flutter pub get` | 0 | 10s | `00-setup.log` |
| `./scripts/dev/setup_git_hooks.sh` | 0 | 1s | `00-setup.log` |
| `git status --short` | 0 (empty) | 0s | `00-setup.log` |

`flutter pub get` left the tree clean, as CLAUDE.md promises.

Friction:

- `docs/guides/onboarding/getting-started.md:44-45` runs `git clone <repository-url>` and then `cd flutter_starter`. The clone creates `flutter-starter`, and an adopter's own repository has their name. Filed **#766**.
- `docs/guides/onboarding/getting-started.md:80` ("4. Generate Code") makes `build_runner build` a numbered setup step. `README.md:31-33` says generated code is committed and should only be regenerated after changing an annotated source. Filed **#767**. (Not run here: the README says not to.)
- `docs/guides/onboarding/getting-started.md:184-188` ranks "`.env` file (highest priority)" above `--dart-define`, while the documented path feeds `.env` in as dart-defines (`--dart-define-from-file`). Filed **#768**.

## Step 1 - rename (Mason, the option the docs recommend)

`fork-and-customize.md` section 1 marks Option A (Mason) "recommended", so Mason was used. Answers were passed as flags so they could be recorded; the docs only say "Answer the prompts". The brick's own strip switches were left at their defaults, because the issue asks for the strip to be done with the tool in step 2.

| Command | Exit | Elapsed | Log |
|---|---|---|---|
| `dart pub global activate mason_cli` | 0 | 33s | `01-rename.log` |
| `mason --version` | **127** (`bash: mason: command not found`) | 0s | `01-rename.log` |
| `export PATH="$PATH:$HOME/.pub-cache/bin"; mason get` | 0 | 24s | `01-rename.log` |
| `mason make flutter_starter_setup --package_name acme_notes --application_id com.acme.acme_notes --ios_bundle_id com.acme.acmeNotes --app_display_name "Acme Notes" --strip_sample_features false --include_tasks_sample true --include_feature_flags_sample true` | 0 | 63s | `01-rename.log` |
| `flutter analyze` | 0, "No issues found!" | 24s | `01-analyze.log` |
| `flutter test --timeout=5m` | 0, "+3536 ~15: All tests passed!" | 557s | `01-test.log` |

The wrapper's log records `exit=0` for the `mason --version` line because a trailing `echo` ran after it. The error text is in the log verbatim.

Brick output:

```
created _mason_hook_only.md
Rewrote 8 feature_clean brick template(s)
Renamed Dart package to acme_notes
Applied "Acme Notes" to 15 Dart/ARB file(s)
Moved MainActivity to match com.acme.acme_notes
Moved MainActivityTest to match com.acme.acme_notes
Updated iOS PRODUCT_BUNDLE_IDENTIFIER to com.acme.acmeNotes
Updated patrol config to com.acme.acme_notes
Rewrote identifiers in 21 platform file(s)
Re-sorted imports and reformatted lib, test, integration_test, tool, examples, docs
Setup complete. Next: flutter analyze && flutter test
```

423 tracked files changed, plus the new `com/acme/` directories and `_mason_hook_only.md`. The brick README documents that file. What was still left afterwards (`git grep -n -i -e 'flutter starter' -e flutter_starter`, outside `docs/`, `bricks/` and `LICENSE`): the `welcome` ARB strings (documented as left for you), `README.md:1` "# Flutter Starter", script header comments in `scripts/ci/*.sh`, tests that pin the template name on purpose, and `tool/golden/stripped/lib/main.dart:200` `title: 'Flutter Starter'`. That last one causes the step 2 failure.

Friction:

- `fork-and-customize.md:22-26` assumes `mason` is on PATH after `dart pub global activate`. It is not by default. Pub prints the fix, but it scrolls past in the activation output. Filed **#769** (P3).

## Step 2 - strip both samples

| Command | Exit | Elapsed | Log |
|---|---|---|---|
| `dart run tool/strip_sample_features.dart` (no flags, to see usage) | 1, prints usage | 2s | `02-strip.log` |
| `dart run tool/strip_sample_features.dart --apply` | 0, "Strip complete." | 30s | `02-strip.log` |
| `flutter pub get` | 0 | 3s | `02-strip.log` |
| `flutter analyze` | 0, "No issues found!" | 20s | `02-analyze.log` |
| `flutter test --timeout=5m --reporter=expanded` | **1 failure** (the log's `exit=0` comes from a pipe through `grep`) | 545s | `02-test.log` |

```
08:34 +2939 ~8 -1: .../test/main_test.dart: MyApp should build MaterialApp with correct title [E]
Expected: 'Acme Notes'
  Actual: 'Flutter Starter'
#4      main.<anonymous closure>.<anonymous closure> (file:///.../test/main_test.dart:73:7)
08:39 +2961 ~16 -1: Some tests failed.
```

Cause: the strip copies `tool/golden/stripped/lib/main.dart` over `lib/main.dart`. The brick's display-name pass (`bricks/flutter_starter_setup/hooks/post_gen.dart`, `_applyDisplayNameToDart`, around line 163) only walks `lib`, `test` and `integration_test`, so it never rewrote the golden. Filed **#759** (P2). Workaround: set `lib/main.dart:200` back to `title: 'Acme Notes',`.

Also found in this step (it came up in step 4): after the strip, `docs/guides/features/routing-guide.md:45,47,67` still uses `AppRoutes.tasks` and `AppRoutes.taskDetailName`, neither of which exists in the stripped tree. Filed **#770** (P3).

Observation, not filed: `flutter test` takes 9 minutes on this host (about 3,500 tests), and the default reporter fills the console with boxed `LoggingService` output from widget tests. That is slow for a newcomer's "verify setup", but it is not a defect, and CI runs the same suite.

## Step 3 - point `BASE_URL` at a real API (https://dummyjson.com)

What the onboarding docs say: set `BASE_URL` in `.env` (from `.env.example`) and pass `--dart-define-from-file=.env` (`README.md:35-41`, `getting-started.md` section 3, `configuration.md`). A `BASE_URL` turns demo mode off. That much worked as documented. The release web build in step 5 compiled with `-DBASE_URL=https://dummyjson.com`, as its log shows.

```
cp .env.example .env
# set BASE_URL=https://dummyjson.com
```

Where the docs stop being enough:

1. **What the API must look like is not on the onboarding path.** The contract exists in `docs/api/features/auth/models.md:143` ("Wire format": `POST /auth/login` with `email`/`password`, returning `user`/`token`/`refresh_token`), but README, getting-started, configuration and `.env.example` never link it. Filed **#760**.
2. **`/v1` is appended to `BASE_URL` without being documented.** `lib/core/network/api_client.dart:87` uses `AppConfig.baseUrl + ApiEndpoints.apiVersion` with `apiVersion = '/v1'` (`lib/core/constants/api_endpoints.dart:11`). Only `models.md:148` mentions it, and nothing can be configured to change it. Filed **#761**.
3. **The response shape, key names, id type and sign-in identifier all differ from dummyjson, and the docs only say "adapt the `@JsonKey` names or `AuthRemoteDataSourceImpl`"** (`models.md:175`). Filed **#762**.

Evidence (`03-backend-probe.log`, `03-dummyjson-login-shape.txt`). The real response was fed to the shipped models by a throwaway test, which was deleted afterwards:

```
$ curl -X POST https://dummyjson.com/v1/auth/login -d '{"username":"emilys","password":"emilyspass"}'
<pre>Cannot POST /v1/auth/login</pre>          HTTP 404
$ curl -X POST https://dummyjson.com/auth/login  -d '{"username":"emilys","password":"emilyspass"}'
HTTP 200 {'accessToken': str, 'refreshToken': str, 'id': int, 'username': str, 'email': str,
          'firstName': str, 'lastName': str, 'gender': str, 'image': str}
$ curl -X POST https://dummyjson.com/auth/login  -d '{"email":"emily.johnson@x.dummyjson.com","password":"emilyspass"}'
{"message":"Username and password required"}  HTTP 400

flutter test test/zz_probe/dummyjson_probe_test.dart --dart-define=BASE_URL=https://dummyjson.com
request URL = https://dummyjson.com/v1/auth/login
isValidEmail("emilys") = false
fromJson threw: _TypeError: type 'Null' is not a subtype of type 'Map<String, dynamic>' in type cast
wrapped fromJson threw: _TypeError: type 'int' is not a subtype of type 'String' in type cast
```

Files an adopter would have to change to sign in against dummyjson. They were left unchanged here, because changing them means writing the adapter:

- `lib/core/constants/api_endpoints.dart:11` - `/v1` prefix
- `lib/features/auth/data/datasources/auth_remote_datasource.dart:40` - sends `email`, not `username`; refresh body and response
- `lib/features/auth/data/models/auth_response_model.dart` - expects a `user` wrapper and a `token` key
- `lib/features/auth/data/models/user_model.dart` and `.g.dart:10` - `id` cast as `String`; `avatar_url` and `name` against `image`, `firstName` and `lastName`
- `lib/features/auth/presentation/screens/login_screen.dart:81` - the form rejects a username (`Validators.isValidEmail`)
- then `build_runner build` and `test/features/auth/data/auth_wire_format_test.dart`

Elapsed: about 6 min, nearly all of it reading docs and code. The commands themselves took under 30s.

## Step 4 - add a feature and route one screen to it

README "Adding a feature" (`README.md:59`) leads to `docs/api/examples/adding-features.md`.

| Command | Exit | Elapsed | Log |
|---|---|---|---|
| `./scripts/dev/create_feature.sh notes` | 0 | 7s | `04-feature.log` |
| `flutter analyze` (scaffold only) | 0 | 8s | `04-analyze-scaffold.log` |
| `flutter test test/features/notes` (first try; my own test assertion was wrong) | 1 | 19s, 13s | `04-test-notes.log` |
| `flutter test test/features/notes` | 0 | 15s | `04-test-notes.log` |
| `flutter analyze` | 0, "No issues found!" | 10s | `04-analyze.log` |
| `flutter test --timeout=5m --reporter=expanded` | **1 failure** | 434s | `04-test.log` |
| `flutter test test/core/routing/routes_registry_test.dart` (isolated) | 1 failure | 10s | `04-test-registry.log` |
| `flutter test test/core/routing test/features/notes` (after moving the route) | 0 | 15s | `04-test-registry.log` |
| `flutter test --timeout=5m --reporter=expanded` (full rerun) | 0, "+2965 ~16: All tests passed!" | 257s | `04-test-rerun.log` |

The scaffold generated domain, data, di and presentation files plus a repository test. It generated no `routing/` module. The data source provider throws `UnimplementedError`, and `NotesScreen` requires an `id`. The linked guide describes a hand-written `Product` feature, never says what the script produced, and ends at "Step 4: Use in UI" with no routing step. Filed **#763**. The routing steps came from `docs/guides/features/routing-guide.md` and from reading `routes_registry.dart`, `home_routes.dart` and `test/helpers/pump_app.dart`. `docs/guides/features/common-tasks.md:239` contradicts routing-guide on hardcoded paths. Filed **#771** (P3).

Wiring done (full diff in `04-wiring.diff`): `AppRoutes.notes = '/notes'` and `notesName`; `lib/features/notes/routing/notes_routes.dart`; `buildNotesRoute(ref)` in `buildAppRoutes`; a "Notes" button on `HomeScreen` calling `context.pushRoute(AppRoutes.notes)`; `NotesRemoteDataSourceImpl` over `ApiClient`, replacing the throwing provider; and `test/features/notes/notes_route_test.dart`, which signs in through an `AuthNotifier` override, taps the button through the real router (`pumpAppRouter`) and finds `NotesScreen`.

Full-suite failure after the first wiring attempt, where the route was appended after `buildHomeRoute(ref)`:

```
02:51 +1586 ~8 -1: .../test/core/routing/routes_registry_test.dart: buildAppRoutes should include auth routes and home route [E]
  Expected: '/'
    Actual: '/notes'
07:02 +2964 ~16 -1: Some tests failed.
```

`routes_registry_test.dart:33-39` requires the home route to come last. Nothing in `routes_registry.dart` says so, and go_router does not need it. Filed **#764** (P3). Workaround: register the notes route before home.

## Step 5 - release Android APK and web build

Documented commands: `flutter build apk --release --dart-define-from-file=.env` (`docs/guides/configuration.md:47`). For the web there is no dedicated build line. The configuration table says web is configured by dart-defines, the same as native, so the same flag was used.

| Command | Exit | Elapsed | Log |
|---|---|---|---|
| `flutter build apk --release --dart-define-from-file=.env` | **1** - NDK 28.2.13676358 auto-install: `java.io.IOException: No space left on device` | 181s | `05-apk.log` |
| `flutter build web --release --dart-define-from-file=.env` | **1** - dart2js: `FileSystemException: writeFrom failed ... (OS Error: No space left on device, errno = 28)` | 64s | `05-web.log` |
| `flutter clean`, then `flutter build web --release --dart-define-from-file=.env` | 0, "Built build/web" (41 MB) | 72s | `05-web.log` |
| `flutter build apk --release --dart-define-from-file=.env` | **1** - `[CXX1101] NDK at ~/Library/Android/sdk/ndk/28.2.13676358 did not have a source.properties file` | 5s | `05-apk.log` |

Both first failures were the host, not the starter: the data volume had 276 MB free (`df -h`). It later recovered to 9.8 GB because something outside this session freed space. The failed NDK install left an empty `~/Library/Android/sdk/ndk/28.2.13676358`. Flutter's own hint is to delete it and let AGP re-download it, but the session's permission policy refused the delete. **The release APK was therefore not built.** To finish this step:

```bash
rm -rf ~/Library/Android/sdk/ndk/28.2.13676358
cd /Users/nguyenanhkiet/Playground/fs-walkthrough
flutter build apk --release --dart-define-from-file=.env
```

That removes only the empty, half-installed NDK directory, which Gradle re-downloads (about 2 GB). It does not touch the starter.

Expected next stop, read from `android/app/build.gradle.kts:108-141` but not observed in a run: with no `android/key.properties`, the build refuses ("Release signing is not configured ... Refusing."), and the escape hatch `flutter build apk --release -PallowUnsignedRelease=true` appears only in that error text. `docs/deployment/android-deployment.md:15` and `configuration.md:47` mention neither. Filed **#765**. Its body says the refusal was read from the build script, not captured from a run.

Web build check: `build/web/assets/` contains `.env.example` (blank by design, documented in `.env.example` itself) and no `.env`.

## Issues filed

| # | Title | Labels |
|---|---|---|
| #759 | fix(tooling): stripping after mason make flutter_starter_setup puts 'Flutter Starter' back as the MaterialApp title and fails test/main_test.dart | type:bug, epic:tooling-ci, P2 |
| #760 | docs(onboarding): 'Connect your backend' never links the auth wire format, so an adopter setting BASE_URL cannot learn what the API must look like | type:bug, epic:docs, P2 |
| #761 | docs(config): BASE_URL is documented as the API base URL, but every request goes to BASE_URL + /v1, which only the auth models reference mentions | type:bug, epic:docs, P2 |
| #762 | docs(auth): no guide for adapting the auth slice to an existing API - flat response, camelCase tokens, int id, username sign-in | type:task, epic:docs, P2 |
| #763 | docs(features): 'Adding a feature' never starts from the create_feature.sh scaffold and has no routing step, so the scaffolded screen is unreachable | type:bug, epic:docs, P2 |
| #764 | test(routing): routes_registry_test requires home to be the last route, an order nothing documents, so appending a feature route fails the suite | type:bug, epic:testing, P3 |
| #765 | docs(deployment): the documented release APK command is refused without a keystore, and the unsigned smoke-build flag is documented only in the Gradle error | type:bug, epic:docs, P2 |
| #766 | docs(onboarding): getting-started clones the repo and then runs cd flutter_starter, a directory the clone never creates | type:bug, epic:docs, P3 |
| #767 | docs(onboarding): getting-started makes build_runner a setup step while README says generated code is committed and only regenerated after a change | type:bug, epic:docs, P3 |
| #768 | docs(config): the fallback chain ranks a .env file above --dart-define, but the documented path feeds .env in as dart-defines | type:bug, epic:docs, P3 |
| #769 | docs(onboarding): the Mason rename steps fail with 'mason: command not found' when ~/.pub-cache/bin is not on PATH | type:task, epic:docs, P3 |
| #770 | docs(routing): after the strip, routing-guide.md's examples still use AppRoutes.tasks and taskDetailName, which no longer exist | type:bug, epic:docs, P3 |
| #771 | docs(features): common-tasks.md navigates by a hardcoded path that routing-guide.md marks as the pattern to avoid | type:bug, epic:docs, P3 |

No status label on any of them (Backlog).

## Not verified here

- The release APK, and therefore what the signing refusal (#765) prints in a run. See step 5.
- Signing in against dummyjson end to end. Per the issue, the gap is recorded rather than an adapter being written.
- Anything on a device, an emulator or a browser session. The web build was compiled, not opened.
