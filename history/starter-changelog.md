# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking

### Fixed

- [UI sign-in examples publish the router session](https://github.com/koniz-dev/flutter-starter/issues/1372): widgets call AuthNotifier.login and observe AuthState; domain use-case examples are explicitly non-UI. A Markdown/Dartdoc guard and real session-graph tests prevent the direct-use-case navigation regression.

- [RASP starts inside the startup guard](https://github.com/koniz-dev/flutter-starter/issues/1358): `bootstrap()` now awaits `raspServiceProvider`'s `startProtection()` inside the guarded startup sequence, so a RASP SDK that throws shows `StartupFailureApp` instead of a black window (the default `NoOpRaspService` does nothing). The freeRASP recipe overrides the provider on Android and iOS only, and the adapter template starts freeRASP once per process, so Try again no longer re-starts it. If you applied the old recipe, delete your `startProtection()` call after `createContainer()` (bootstrap now makes it), move any `onThreatDetected` subscription to just above the new call, and add the platform guard.

- [Text-field outlines meet 3:1 contrast](https://github.com/koniz-dev/flutter-starter/issues/1359): the unfocused `border` and `enabledBorder` in both themes were translucent `Colors.black12` (1.32:1 on the light background) and `Colors.white24` (2.15:1 on the dark one), below WCAG 2.1 SC 1.4.11. Both now use a new opaque `AppColors.outline` (`#6C757D`), 3.55:1 to 4.69:1 on every theme background and surface, so unfocused fields have a visibly darker (light) or lighter (dark) outline. Regenerate any golden of your own that shows a text field.

- [Dio-to-http migration keeps the network contract](https://github.com/koniz-dev/flutter-starter/issues/1360): the sketch in `docs/architecture/design-decisions.md` told you to rewrite `ApiClient` to return `http.Response` and remove the interceptors, which silently drops SSL pinning, 401 refresh and forced logout, the response cache's credential guard, the release HTTPS-only redirect refusal and the `API_TIMEOUT` deadline. It now swaps an `HttpNetworkClient` adapter in behind `INetworkClient`, keeps `ApiClient`'s `NetworkResponse` verbs, and tables every behaviour the Dio chain carries with its `package:http` replacement. The Provider, Result -> Exceptions and Result -> Either sketches now match the real code, and the BLoC pointer to a guide with no BLoC content is gone. If you followed the old sketch, check your http client for the behaviours in that table.

- [Session-timeout blueprint ends an expired session on resume](https://github.com/koniz-dev/flutter-starter/issues/1362): a suspended app runs no timers, and the `SessionActivityTracker` in `docs/guides/security/blueprints.md` called `onUserActivity()` on resume, which reset the timer without checking the elapsed time, so an app left in the background never timed out. `SessionManager` now has `onResume()`, which signs out when the time since the last activity is at least `sessionTimeout` and only then restarts the timer, and the tracker calls it on resume. If you copied the old recipe, add `onResume()` and call it from your resume handler instead of `onUserActivity()`.

- [The app keeps the device locale's region](https://github.com/koniz-dev/flutter-starter/issues/1363): `LocalizationService.deviceLocale()` and a stored language choice resolved to the region hard-coded in `SupportedLocale` (`en_US`, `es_ES`, `ar_SA`), and `MaterialApp`'s default resolution mapped a requested `en_GB` back to `en_US`, so an `en_GB` device read 9 March as `3/9/2026` and an `es_MX` device was shown euros. The locale now carries the region the device pairs the language with (new `LocalizationService.withDeviceRegion`), `MyApp` passes the new `LocalizationService.resolveLocale` as `localeListResolutionCallback` so `Localizations.localeOf` reports it, and the language pickers match the current locale by language. `Localizations.localeOf` and `localeStateProvider` can now hold a locale outside `LocalizationService.supportedLocales` (`en_GB`, `ar_EG`): compare by `languageCode`, not by equality with a `SupportedLocale.locale`.

- [The language dialog scrolls in phone landscape](https://github.com/koniz-dev/flutter-starter/issues/1364): the dialogs opened by `LanguageSwitcher` and `LanguageSwitcherMenuItem` held their four locale tiles in a non-scrolling `Column`, so at 844x390 or 800x360 they overflowed even at the default text size and clipped the last locales. The list now scrolls inside the dialog, with the title and Cancel pinned. If you added locales or copied the dialog, it now has room for them.

- [The setup brick keeps MainActivity for the template's own id](https://github.com/koniz-dev/flutter-starter/issues/1365): with `application_id` set to `com.example.flutter_starter`, an id under it such as `com.example.flutter_starter.dev`, or (on macOS or Windows) a case variant such as `com.Example.flutter_starter`, `mason make flutter_starter_setup` deleted `MainActivity.kt` and the Patrol `MainActivityTest.java` while logging that it moved them, leaving the Android app with no launcher activity. Both now end up in the id's package directory. A `.DS_Store` left by Finder in the template package no longer keeps the emptied `com/example` tree. If you ran the brick with one of those ids, restore both files from the template into `android/app/src/main/kotlin/<id path>/` and `android/app/src/androidTest/java/<id path>/` and set their `package` line to your id.

- [The setup brick keeps a `com.example` iOS bundle id](https://github.com/koniz-dev/flutter-starter/issues/1366): with an `ios_bundle_id` starting with `com.example` (the brick's default does), `mason make flutter_starter_setup` turned it into `<application_id organization>.<rest>` in `ios/ExportOptions.plist`, `ios/fastlane/Appfile`, `macos/Runner/Configs/AppInfo.xcconfig` and the macOS `project.pbxproj`, while the iOS `project.pbxproj` kept the real id; an `application_id` under `com.example` was doubled the same way in the Linux and Windows runners. The hook now rewrites each file in one pass. The fork-and-customize section 2 recipe had the same chain for macOS and now leaves an id it has set alone. If you renamed with such an id, set those files' bundle id back to your `ios_bundle_id` (and your Linux `APPLICATION_ID` to your `application_id`).

- [The demo sign-in removal steps leave `flutter test` green](https://github.com/koniz-dev/flutter-starter/issues/1367): the steps in `docs/guides/onboarding/getting-started.md` delete the "Signing In Before You Have a Backend" section, but `README.md` links to it, so after following them `test/docs/doc_links_test.dart` and `dart run tool/check_docs.dart` failed on a missing anchor. Step 2's `git grep` now also searches `README.md` for the section's anchor and names that link, and `test/tooling/demo_removal_steps_test.dart` fails if any markdown file outside the deleted or edited set links to the section. If you already removed the demo, delete or reword the "how to remove it" link in your `README.md`.

- [A failed legacy-key read no longer advances the storage schema](https://github.com/koniz-dev/flutter-starter/issues/1369): `MigrationV1ToV2` read its legacy keys with `getString` / `containsKey`, which on `SecureStorageService` answer `null` / `false` when the Keychain or Keystore read throws (for example, a Keystore key lost after an Android backup restore). An unreadable value was taken as "nothing to migrate", the stamp moved to v2, and the value was never migrated. On a storage implementing `IStrictStringRead` the migration now reads through `getStringOrThrow` and throws `MigrationException`, so startup reports the failure with the stamp still at v1 and the next launch retries. `docs/guides/features/storage-migration-guide.md` now teaches the same strict reads (`readLegacy` / `hasLegacy`). If you wrote your own migrations from the old guide and run them on secure storage, read their legacy keys the same way.

- [An offline cold start keeps activated remote flag values](https://github.com/koniz-dev/flutter-starter/issues/1370): `FeatureFlagsRepositoryImpl.initialize()` only read the remote source once both the SDK `initialize()` and the first `fetchAndActivate()` had succeeded, so on an offline cold start (the SDK initializes, only the fetch fails or times out) every flag fell back to its local definition for the rest of the session, hiding the values the SDK activated on an earlier launch. Remote reads now start as soon as the SDK initializes, and a failed or timed-out fetch keeps them; a failed or timed-out SDK initialization still falls back locally. If your `FeatureFlagsRemoteDataSource` throws from `getRemoteFlag` / `getAllRemoteFlags` until a fetch succeeds, make it return `null` / `{}` instead, as a vendor SDK serving no activated values would.

## [5.0.3] - 2026-11-24

### Fixed

- [Correct rename/configuration guidance](https://github.com/koniz-dev/flutter-starter/issues/1348): remove the stale count of imports needing sorting after rename and the misleading suggestion to add the existing EnvConfig.load call when configuration is supplied through build defines.

- [Finish release and hook audit findings](https://github.com/koniz-dev/flutter-starter/issues/1347): release formatting fails before tests or mutations, changelog headings strip version comments, tag/deletion-only pushes skip tests while branch pushes test the working tree, and docs state PowerShell7+ plus whole-repository pre-commit export costs. Part of the [November audit checklist](https://github.com/koniz-dev/flutter-starter/issues/1343).

- [Prevent editing a pending task snapshot](https://github.com/koniz-dev/flutter-starter/issues/1346): disable the Edit menu item while that task is being mutated, so a title edit opened after a pending toggle completes keeps the updated completion state.

- [Prove auth screen disposal and identify autofill usernames](https://github.com/koniz-dev/flutter-starter/issues/1345): login/register email fields advertise username before email for credential pairing. Pending-submit navigation tests verify the old screen is disposed before completing the request, and detect removal of either mounted guard.

- [Remove Mason through the strip tool](https://github.com/koniz-dev/flutter-starter/issues/1342): onboarding instructions name --remove-bricks and explain that deleting bricks/mason.yaml by hand leaves broken test imports as well as documentation links; regression guards keep this warning in place.

- [Clarify release TLS configuration](https://github.com/koniz-dev/flutter-starter/issues/1341): document that direct API and realtime TLS handshakes in staging/production release use the default or pinned context, and explain where to load private CAs and client certificates instead of relying on HttpOverrides.

## [5.0.2] - 2026-11-18

### Fixed

- [TLS and pinning failures name the certificate](https://github.com/koniz-dev/flutter-starter/issues/1326): a handshake rejected by certificate pinning or an untrusted CA surfaced as a generic connectivity error. `DioExceptionMapper` now maps a `TlsException` to `NetworkException` with code `BAD_CERTIFICATE` (a `SocketException` stays `NETWORK_ERROR`). Code that matched the old connectivity code for these failures should match `BAD_CERTIFICATE` too.
- [Auth forms work from the keyboard](https://github.com/koniz-dev/flutter-starter/issues/1327): login and register move between fields with Next and submit with Done, offer email, password and name autofill hints inside an `AutofillGroup` (saved only on a successful sign-in), and have a show/hide password button with localized tooltips (new ARB keys `showPassword` and `hidePassword`). A whitespace-only name is rejected, and the demo sign-in card's title wraps instead of overflowing at large text sizes.
- [v4 to v5 upgrade notes](https://github.com/koniz-dev/flutter-starter/issues/1328): the upgrade guide gains a "v4 to v5" section: add `material_ui` and `cupertino_ui` to `pubspec.yaml`, copy `UIApplicationSceneManifest` into `Info.plist`, and pass an API URL to release builds. The v5.0.0 release notes are corrected the same way.
- [Audit P3 fixes](https://github.com/koniz-dev/flutter-starter/issues/1329):
  - Network: a query value that cannot be percent-decoded is redacted whole in logs, and a URL carrying a redacted query parameter bypasses the HTTP cache (`sensitiveKeyRuleVersion` is now 4).
  - Logging: `FileLogOutput` no longer installs a sink opened by an `init` that raced `destroy`, `clearLogs` or a rotation; production web builds log to the console instead of trying a file; `PerformanceScreenMixin` strips only a trailing `State` from the screen name.
  - Tooling: `build_all.sh` production on macOS tries `flutter build ipa` and falls back to an unsigned `flutter build ios`, and uses a temporary file instead of a fixed `/tmp` path; `setup_branding.sh` restores the Xcode asset-symbol setting `flutter_launcher_icons` resets; the iOS and macOS workspace `Package.resolved` files are committed; the Gradle wrapper pins `distributionSha256Sum` (update it when you bump the wrapper) and `mason_cli` is pinned to 0.1.4 in `scripts-smoke.yml` and in the docs that tell you to install it.
  - Docs: getting started lists libsecret on Linux and the 8-character password minimum; the realtime example uses `ref.watch`; Mason instructions are stripped with the bricks.

## [5.0.1] - 2026-11-17

### Fixed

- [Open the log file once](https://github.com/koniz-dev/flutter-starter/issues/1321): `package:logger` calls `init()` on its output again, so `FileLogOutput` opened the log file twice and replaced the first sink unclosed - log lines around startup could be lost and a file descriptor leaked. It now opens once.

## [5.0.0] - 2026-11-17

### Breaking

- [Utility validation contracts](https://github.com/koniz-dev/flutter-starter/issues/1284): phone validation now requires 7–15 digits with optional initial + and space/hyphen separators; URL validation requires http/https/ftp/ws/wss and valid ASCII DNS/punycode or IP hosts and unsigned ports. Convert international domains to punycode and apply a separate policy for other URI schemes. JsonHelper.getInt now returns null for fractions, overflow or target rounding; callers needing truncation must validate range and truncate explicitly, and large identifiers should remain strings.

- Forks with custom iOS AppDelegate code must follow the UIScene lifecycle migration: conform to FlutterImplicitEngineDelegate and register plugins through the engine bridge in didInitializeImplicitFlutterEngine. Also copy the `UIApplicationSceneManifest` dictionary from the starter's `ios/Runner/Info.plist` into yours: without it the app does not adopt scenes. Preserve custom native lifecycle behavior when merging; see docs/deployment/ios-deployment.md and the "v4 to v5" section of docs/guides/migration/upgrading-this-starter.md. Existing deployment targets and signing settings are unchanged.

- Custom widgets, themes or design-token adapters using design-library types must switch their Material/Cupertino imports to material_ui/cupertino_ui so their public types match the starter. Retain the l10n.yaml header and its delegate adapters when regenerating translations; update relative imports if relocating generated output. See the standalone UI section of upgrading-this-starter.md.

- **Partially persisting custom refresh callbacks must store the complete credential pair.** A callback that writes only the refresh token and returns an unpersisted access token now cancels without replay or teardown. Persist both access and refresh before returning, or mutate neither and return the access token. Ambiguous ABA states also cancel safely; see the [network callback migration](https://github.com/koniz-dev/flutter-starter/blob/main/docs/api/core/network.md).

- **Custom ITokenStore implementations require versioned adoption methods.** Add credentialRevision, getAccessTokenSnapshot and setAccessTokenIfCurrent with shared mutation revisions and synchronous conditional reservation; an asynchronous get/set fallback is unsafe. See the [storage API migration](https://github.com/koniz-dev/flutter-starter/blob/main/docs/api/core/storage.md#versioned-refresh-result-adoption).

- **Custom auth datasource logout signature changes.** Custom `AuthRemoteDataSource` implementations must accept the new optional `accessToken` argument on `logout` and use it as the Authorization header when their server requires it.

- **`IAuthController` and `authControllerProvider` are removed.** Nothing in the starter read them; the UI uses the generated `authProvider`. If your code typed against `IAuthController`, `AuthStateSnapshot` or `ControllerStateSnapshot`, or read `authControllerProvider` or `AuthNotifier.snapshot`, read `authProvider` / `authProvider.notifier` instead, or declare the contract in your own code. `AuthNotifier`'s methods are unchanged.

- **Staging and production builds need your API URL.** `scripts/ci/build_all.sh` and the manual `build.yml` workflow no longer fall back to `https://api.example.com`. Set `BASE_URL_STAGING` / `BASE_URL_PRODUCTION` in the environment (for `build.yml`: its `base_url` input, or a repository variable or secret of those names). A missing, non-https or `example.com` URL is refused before anything is built; copy `scripts/ci/release_base_url.sh` together with the updated script and workflow.

- **Android builds on Flutter 3.50 need the newer toolchain.** Flutter 3.50 refuses Android Gradle Plugin below 9.1.1 and Kotlin below 2.4.10. Copy the three versions: Gradle 9.5.0 in `android/gradle/wrapper/gradle-wrapper.properties`, AGP 9.3.1 and Kotlin 2.4.20 in `android/settings.gradle.kts`. `tool/check_android_toolchain.dart` now enforces these floors; they also build on Flutter 3.47.

- **Dependency floors moved after v4.0.0.** `patrol` ^4.11.0 needs `patrol_cli` 4.9.0 (reinstall the CLI); `equatable` ^3.0.0 removes `EquatableMixin`, so write `with Equatable` where your code said `with EquatableMixin`; `material_ui` ^1.11.0 and `cupertino_ui` ^1.1.6 are new direct dependencies: add both to your `pubspec.yaml` (see the "v4 to v5" section of docs/guides/migration/upgrading-this-starter.md); `go_router` ^18.1.4 and the code generators (`build_runner` 2.17.1, `build` 5.0.0) are routine: run `flutter pub get` and regenerate.

### Fixed

- [Keep the test suite green after a manual rename](https://github.com/koniz-dev/flutter-starter/issues/1319): after renaming by hand as `fork-and-customize.md` Option B documents, two setup brick tests failed; they now skip once the project is renamed.

- [Close the 2026-11-17 audit's P3 findings](https://github.com/koniz-dev/flutter-starter/issues/1310): `OptimizedListView` no longer re-sends a failed prefetch on every scroll, keeps a fixed `itemExtent` off its error slot, and offers Load More for an empty first page; the not-found screen scrolls; task ids are percent-encoded in paths; nested and percent-encoded URL credentials are redacted in logs; a late logout no longer undoes a newer sign-in. Tooling: workflows that run on push group runs per commit and never cancel a push run; `check_docs` reads reference, angle-bracket and HTML links; `test_coverage.sh --html` asks you to install lcov instead of installing it. Docs: brick instructions are removed with `--remove-bricks`, and `security/audit.md` re-rates obfuscation, manifest and ATS entries.

- [Cache responses that vary only on Accept-Encoding or Origin](https://github.com/koniz-dev/flutter-starter/issues/1308): the URL cache refused every response with a `Vary` header, so against a real API (gzip, CDN, CORS) it stored nothing. Those two fields are now allowed; any other `Vary` still prevents storage.

- [End the realtime client with the session](https://github.com/koniz-dev/flutter-starter/issues/1309): the client created through `realtimeClientFactoryProvider` is disconnected on logout, forced logout and every sign-in, and the next read gets a fresh one. If you enabled realtime, watch the client and reconnect when signed in (see the network API doc).

- [Offer Home from a root tasks list](https://github.com/koniz-dev/flutter-starter/issues/1285): reached by a deep link or a sign-in redirect, the tasks list shows a Home button instead of leaving the user with no way out.

- [Close the 2026-11-14 audit's documentation findings](https://github.com/koniz-dev/flutter-starter/issues/1268): configuration (unknown `ENVIRONMENT` refuses to start, empty `ENABLE_SSL_PINNING` is unset, configuration needs a fresh `flutter run`), localized image directories, device ids, the refresh selection step, and a new security-audit note that on web the session is per tab while the tokens are shared.

- [Reject duplicate demo registration](https://github.com/koniz-dev/flutter-starter/issues/1286): the offline demo answers an already-registered email with a 409, as a backend would, instead of overwriting the account and breaking the demo card's credentials.

- [Remove the unused `checkExamples` key](https://github.com/koniz-dev/flutter-starter/issues/1287): dropped from the four ARB files; `AppLocalizations.checkExamples` no longer exists.

- [Find the exported IPA by glob](https://github.com/koniz-dev/flutter-starter/issues/1292): the iOS build lanes clear `build/ios/ipa/` and take the single `.ipa` Xcode exported (new `fastlane/ios_ipa.rb`) instead of assuming `Runner.ipa`; the commented App Store upload step in `deploy-ios.yml` does the same.

- [Ignore golden failure images](https://github.com/koniz-dev/flutter-starter/issues/1290): `.gitignore` ignores `/test/**/failures/`, where a failed golden comparison writes its diff images; a `failures/` directory under `lib/` stays tracked.

- [Describe workflow triggers accurately](https://github.com/koniz-dev/flutter-starter/issues/1291): the `coverage.yml` header, `test-coverage.md` and `scripts/dev/setup_ci.dart`'s prompt and reports now say that only the `deploy-*` workflows ship a commented trigger, enabled with `--deploy-trigger`.

- [Let the strip run past pub's own lockfile re-pin](https://github.com/koniz-dev/flutter-starter/issues/1289): on a Flutter other than the one that resolved `pubspec.lock`, `tool/strip_sample_features.dart` (and the setup brick that runs it) no longer refuses the lock `dart run` just re-pinned; it notes the change and still refuses any other edit.

- [Anchor Dart formatting to the project root](https://github.com/koniz-dev/flutter-starter/issues/1288): `scripts/dev/format_dart.sh` changes to the project root first, so `--check` run from a subdirectory checks the project instead of passing having checked nothing.

- [Define phone, URL and integer conversion contracts](https://github.com/koniz-dev/flutter-starter/issues/1284): validate supported network URLs and basic formatted phone numbers, and return only exact target-representable signed 64-bit integers.

- [Keep calendar helpers in the receiver time zone](https://github.com/koniz-dev/flutter-starter/issues/1283): preserve UTC/local day boundaries and compare today/yesterday/tomorrow against a clock in the same zone, retaining calendar-day handling across DST.

- [Follow runtime system locale changes](https://github.com/koniz-dev/flutter-starter/issues/1282): refresh the app locale on platform changes and after mounting, preserve stored or manual choices, and prevent delayed reads from overwriting a new selection.

- [Handle wrongly typed preferences](https://github.com/koniz-dev/flutter-starter/issues/1281): report non-string preferences as storage failures so startup can use the device locale and tasks can report a storage error. Preserve malformed data and migration idempotence without swallowing unrelated read failures.

- [Redact nested fragment credentials](https://github.com/koniz-dev/flutter-starter/issues/1280): hide sensitive query values after plain fragment prefixes or earlier equals signs, including nested query markers and complete secret tails, while preserving public route fragments.

- [Complete sign-in persistence](https://github.com/koniz-dev/flutter-starter/issues/1279): replace the whole credential pair, clear failed writes before another sign-in persists, and keep failed replacements out of stored/visible sessions. Coordinate restore, refresh and 401 handling with pending persistence, preserve remote-failure sessions and reject stale refresh/listener work.

- [Fastlane Play Store metadata](https://github.com/koniz-dev/flutter-starter/issues/1267): replace unsupported whatsnew_directory with an absolute metadata_path root and verify all five upload calls against documented Supply options. Correct root-shell commands, per-lane credential guidance, app/store changelog separation and automatic IPA build troubleshooting.

- [One-time setup brick](https://github.com/koniz-dev/flutter-starter/issues/1266): reject already customized package/platform identifiers before Mason writes files and direct later id changes to the manual guide. Avoid false package/iOS rename logs for unchanged values and preserve pubspec line endings; first-run setup and repeated-run refusal are verified.

- [Guarded deploy template API URLs](https://github.com/koniz-dev/flutter-starter/issues/1265): all five commented Android/iOS/Web deploy builds accept repository-variable URLs with a secret fallback and reject missing, non-HTTPS or placeholder URLs before invoking Flutter. Group Android keystore writes for workflow lint and deploy build/web to Vercel.

- [Safe core customization guidance](https://github.com/koniz-dev/flutter-starter/issues/1264): replace incomplete localization and secure-storage deletion recipes with load-bearing module guidance, keeping one locale or migrating credential consumers deliberately. Correct the description of pub outdated.

- [Auth documentation examples](https://github.com/koniz-dev/flutter-starter/issues/1263): publish UI login through AuthNotifier, inject the configured sign-out action into the session blueprint, document logout revocation credentials, and refresh only with expired-session sign-out and repository-owned persistence. Executable documentation regressions cover the session and import-boundary behavior.

- [Immediate sign-out navigation](https://github.com/koniz-dev/flutter-starter/issues/1262): drop the in-memory user before awaiting remote logout so the router leaves private screens while revocation is pending. Keep loading/error reporting and local teardown behavior; existing logout/restore acceptance goldens remain unchanged.

- [Localized HTTP rejection messages](https://github.com/koniz-dev/flutter-starter/issues/1261): distinguish request rejection (including 400/409) and rate limiting (429) from server outages on login and registration in English, Spanish, Vietnamese and Arabic. Preserve existing failure types, refresh/retry behavior, typed client errors and 5xx messages.

- [HTTP cache credential isolation](https://github.com/koniz-dev/flutter-starter/issues/1260): share sensitive-header detection with logging, bypass credentialed requests, refuse header-dependent Vary responses and purge indexed legacy cache entries. Ignore unindexed or uncertified bodies and require successful body/timestamp writes before cache admission; anonymous caching remains enabled.

- [Orphaned auth sessions](https://github.com/koniz-dev/flutter-starter/issues/1259): remove persisted credentials and per-session HTTP cache when the cached user cannot be restored, prevent stale restores from deleting a newer session, and skip 401 refresh when the credential snapshot has no access token.

- **A Patrol run with skipped tests is no longer green.** The E2E workflow and `scripts/test/run_e2e_tests.sh` both run `scripts/test/check_patrol_summary.sh`, which passes only when every collected test ran and passed (`Total` not 0, `Failed` and `Skipped` 0, `Successful` equal to `Total`). The local script used to exit 0 on an empty or fully skipped run. Copy the new script together with the workflow.

- **The Android build on the current stable is checked every week.** `build.yml`'s "Android on JDK 25" job also runs on a weekly schedule in the template repository, so a Flutter stable that raises its Gradle, AGP or Kotlin floors turns a run red. A repository created from the template skips it; `docs/deployment/summary.md` says how to enable it there.

- **The docs say the committed lock follows the current stable.** On an older Flutter that still meets the 3.47 floor, `flutter pub get` rewrites the SDK-pinned entries of `pubspec.lock`; the README, CONTRIBUTING and the getting-started guide say not to commit that diff.

- **Architecture and API docs match the code again.** The layer diagram and its Mermaid block, the feature brick's generated names, the tasks date formatting, ADR 0001/0002 status and several snippets were corrected; presentation snippets note the text-literal guard.

- **`AppTheme` builds from the `AppDesignTokens` contract.** `AppTheme.light(tokens)` and `AppTheme.dark(tokens)` build a theme from any implementation of the contract; `lightTheme` and `darkTheme` are those builders applied to the default tokens and look the same as before. To restyle the app, implement `AppDesignTokens` and pass it to the builders in `lib/main.dart`.

- **Scaffolded features come with a route module.** `mason make feature_clean` and both `create_feature` scripts now generate `lib/features/<name>/routing/<name>_routes.dart`, with a path and name constant of its own. The feature guide says how to move them into `AppRoutes` and register the route; features you already scaffolded are unaffected.

- **Scripts smoke stays green in a stripped project.** After a sample strip or `--remove-bricks`, the setup-brick and manual-rename jobs skip the steps that need Mason or the strip tool, with a notice, instead of failing on files the strip removed.

- **The feature brick refuses to overwrite an existing feature.** `mason make feature_clean` for a name that already has `lib/features/<name>` or `test/features/<name>` now stops before writing anything, as `create_feature.sh` does. It used to prompt file by file, or fail part-way with no terminal.

- **Release scripts work from any directory and check history first.** `generate_changelog.sh` and `release.sh` operate on the repository root wherever they are run from (the changelog script used to write a stray `CHANGELOG.md` into the current directory). On a first release with no tag, `release.sh` refuses before running the tests and names `RELEASE_CHANGELOG_SINCE=<ref>`.

- [Monorepo sample stripping](https://github.com/koniz-dev/flutter-starter/issues/1214): scope the Git dirty check to the app directory so untracked, unstaged or staged sibling edits no longer require force. Preserve protections for app edits, normalized overwrite targets and hidden index changes; real monorepo fixtures verify sibling contents and Git state remain unchanged.

- [Native configuration migrations](https://github.com/koniz-dev/flutter-starter/issues/1213): retain iOS/macOS SwiftPM integration, pinned package resolutions and CocoaPods fallback, and adopt the iOS UIScene implicit-engine plugin-registration callback. Fresh clones configure both platforms on Flutter 3.50 without changing tracked files; unsigned iOS compilation is verified.

- [Flutter 3.50 compatibility](https://github.com/koniz-dev/flutter-starter/issues/1225): migrate runtime UI, tests, examples, feature generators and strip fixtures to the standalone Material/Cupertino libraries, preserve generated localization delegates through supported header adapters, and keep the architecture guard effective. Covers the coordinated scopes #1226–#1236.

- **Local feature-flag overrides apply only with debug features enabled.** Single, batch and complete flag reads ignore stored debugging overrides when AppConfig.enableDebugFeatures is false. Production/staging defaults honor remote values; explicit debugging opt-in preserves overrides without deleting saved data.

- **Language selection tolerates widget disposal during preference writes.** Callbacks capture the notifier before awaiting storage and check the owning widget before updating state or navigating. Dialogs that outlive their consumer ignore further selections instead of reading a stale ref.

- **Success snackbar text stays readable in dark themes.** An explicit light inverse-text token gives the green success fill 5.14:1 contrast in both themes. Widget contrast tests cover success and error snackbars in light and dark modes.

- **Nonpositive API_TIMEOUT disables the total request deadline.** Zero and negative values allow requests to proceed while phase timeouts and caller cancellation remain active. Documentation states that the shipped 30-second total/receive budgets need an increased total budget for receive-timeout retries.

- **Refresh-result adoption preserves newer credentials.** The interceptor selects certified snapshots, conditionally stores nonpersisting callback results and avoids duplicate repository writes. Conflicts and uncertain reads fail without teardown; a superseded replay 401 cannot clear a newer rotation. Queued requests select fresh current tokens.

- **Token stores support versioned conditional refresh-result adoption.** Certified snapshots reject uncertain reads; conditional writes reserve order before awaiting storage. Superseded platform calls repair known newer state even when a lost acknowledgement reports failure.

- **URL redaction covers OAuth fragment credentials and WebSocket tickets.** Query and fragment parameters share credential-key rules while ordinary anchors/body fields remain readable. Ticket-authenticated responses bypass the HTTP cache, and a rule-version migration discards older cached entries.

- **Uncaught-error redaction covers relative request paths and chained handlers.** Exceptions, context and lazy diagnostic values are sanitized before previous Flutter/platform handlers receive them; URL wrapper punctuation and diagnostic visibility are preserved, and ordinary exceptions retain identity and stack.

- **Shell scripts and Git hooks retain LF on Windows checkouts.** Git attributes prevent core.autocrlf from converting shell entrypoints to CRLF, which previously made commit-msg and other Bash scripts fail.

- **Session-token documentation uses lifecycle contracts and avoids credential logging.** Examples use ITokenStore for credential access and the auth repository/controller for sign-out; raw secure-storage examples cover non-session secrets. A Dart-token documentation guard rejects unsafe key operations and token-value prints. The guard declares analyzer as a dev dependency at its existing locked version and archive hash.

- **Auth forms validate the same email they submit.** Login and registration trim surrounding email whitespace before validation, allowing autofill/keyboard suggestions with trailing spaces. Password input remains unchanged.

- **Realtime clients report remote closes and clean up owned sockets.** A server close emits RealtimeConnectionClosed on the message stream error channel after disconnection; the stream remains open for reconnection. Handle stream errors even for a clean server close. Override realtimeClientFactoryProvider for automatic disconnect on provider disposal; direct overrides of realtimeClientProvider retain responsibility for their own cleanup.

- **API performance helpers redact URL credentials.** Trace names and HTTP path attributes now use the existing URL redactor, removing userinfo and sensitive query values before a performance backend records them. Canonical HTTP fields take precedence over custom attributes to prevent an unsafe path override; plain paths retain their current attributes.

- **Feature flag refresh keeps activated remote values available.** Reads continue using the last activated values during a refresh and after a failed or timed-out fetch. Initial initialization still has bounded local fallback, and a timed-out vendor fetch cannot overlap a new activation.

- **Token refresh is shared across manual and interceptor callers.** Concurrent refreshes in one session now use one remote rotation and persistence result. Failed operations can retry, while a new session does not join or accept the old session’s refresh.

- **Sign-out clears local session state before waiting for the server.** A slow logout endpoint no longer leaves a restorable user or tokens on the device. The original refresh token and bearer are retained only for server revocation; remote failures remain visible.

## [4.0.0] - 2026-11-08

### Breaking

- **Configure a real API URL before using Fastlane build or store lanes.** Pass `base_url:` explicitly or set `BASE_URL_STAGING` / `BASE_URL_PRODUCTION` for the selected `environment:`. The lanes no longer fall back to `https://api.example.com`; copy the updated Fastfile and release environment helper together.
- **Bind sign-out when customizing authentication.** A container without `authModuleOverrides` now throws when sign-out is invoked. Keep those overrides or provide your own `signOutProvider` binding; declare custom home navigation through `HomeDestination` when adopting the updated home screen.

### Fixed

- **Android builds leave Kotlin session caches untracked.** The Android ignore rules now exclude `.kotlin/`, preventing generated compiler session data from being committed.

- **Key-value storage documents mutation failures.** IKeyValueStore now tells callers to check false results before reporting success, deleting migration source data or considering session cleanup complete.

- **Task reads respect pending session cleanup.** Cleanup becomes pending immediately, concurrent wipes share one deletion, and epoch changes clear the in-memory snapshot. Detail reads wait for cleanup and reject stale session results, preventing the next user from loading the prior user's tasks while deletion runs or after it fails.

- **Task persistence rejects false storage results.** Failed writes reach callers as failures, failed deletion triggers cleanup fallback, and the next session stays empty if both fail. Task creation settles a pending wipe before writing, so storage recovery cannot report success then delete the newly created task.

- **Auth reports rejected profile cache mutations.** A false profile write or deletion now raises CacheException. Rejected profile deletion still attempts token cleanup, so access and refresh tokens are cleared independently before failure is reported.

- **Storage migrations stop after rejected writes or deletions.** Migration v1 to v2 checks every mutation result before deleting source keys or advancing the schema. Partially applied migrations can retry safely after storage recovers.

- **Complete the remaining runtime and tooling audit fixes.** Task dates follow the screen locale, nullable lazy initializers cache null, remote feature flags have bounded fallback and safe refresh retries, and native staging/production API redirects stay on HTTPS. Generated feature tests cover the domain layer; deploy and Fastlane examples now use valid credentials/release-note formats and explicit setup paths.

- **One canonical feature creation guide.** Customization now links to Adding a New Feature instead of duplicating an incomplete tutorial that omitted localization and navigation.

- **Authentication DI documentation matches all three seams.** Provider, security and retry guides now include sign-out alongside refresh and session termination, and the contracts map reflects the live sign-out and feature-flag declarations.

- **Auth removal documentation covers every shared seam.** The canonical procedure now covers the session notifier, bootstrap and REST bindings, sign-out action, shared test helpers and source-reading documentation consumers. Onboarding links to it instead of prescribing obsolete router edits.

- **Sample stripping protects uncommitted work.** Both strip modes refuse dirty or unverifiable Git trees and edited overwrite targets, including hidden index changes. `--force` is an explicit override. Run stripping before customization: committed edits can still be replaced by golden files.

- **Optional GraphQL template uses configured pinning and memory-only caching.** The native example refuses insecure release endpoints and misconfigured pins, clears its session cache and closes its transport on disposal. Documentation explicitly requires browser adaptation and application-provided refresh/replay/logout handling.

- **Git hook setup warns about shadowed same-name hooks.** Both setup scripts now name every old hook that will stop running, including Git LFS pre-push, and advise merging or chaining its commands without overwriting tracked hooks.

- **OptimizedImage preserves proportions while bounding decode size.** A ResizeImage adapter computes aspect-preserving physical-pixel sizes and clamps both axes to at least one pixel, so non-square images keep their proportions and very thin images still decode.

- **OptimizedListView renders returned pages.** The widget now appends the items returned by `onLoadMore` and honours its `hasMore`. Equal input rebuilds preserve pages; changed input resets pagination and ignores stale requests.

- **Release lanes choose API URLs by environment.** Android and iOS lanes now select `BASE_URL_STAGING` or `BASE_URL_PRODUCTION` from the resolved `environment:`, regardless of lane name. An explicit `base_url:` still wins.

- **Uncaught error reports redact URL credentials.** Framework image errors and platform errors now remove URL userinfo and sensitive query values before file logging and crash reporting, including secrets following valid URL apostrophes. Ordinary errors and stack traces are preserved.

- **Code findings from the 2026-11-01 audit.**
  - **Secondary text is visibly secondary.** The themes now set
    `onSurfaceVariant` to the `textSecondary` tokens. Before, it fell back to
    `onSurface`, so text such as home's hint line and text field labels
    rendered in the primary text colour. If your own widgets use
    `onSurfaceVariant`, they now render grey.
  - **Store lanes need a real API URL.** The Fastfile lanes no longer default
    to `https://api.example.com`. Pass `base_url:` or set
    `BASE_URL_PRODUCTION` / `BASE_URL_STAGING`; otherwise the lane stops
    before it builds.
  - **Configuration refusals say so.** A build-configuration refusal at
    startup (bad `ENVIRONMENT`, non-https `BASE_URL`, misconfigured
    pinning) throws `StartupConfigurationError`. The failure screen now
    says to rebuild and offers no retry.
  - **`AppConfig.getDebugInfo()` redacts `baseUrl`.**
  - **`LazyInitializer` and `DeferredImportLoader` handle `reset()`.** They
    ignore a call that finishes after `reset()`.
  - **Tasks sample:**
    - The row's checkbox and menu name their task; the menu uses a new ARB
      key, `taskActions`.
    - Row colours meet WCAG AA.
    - A missing title shows `taskTitleRequired`.

- **Hooks and tooling from the 2026-11-01 audit.** If you copied any of
  these, take them again:
  - `.githooks/commit-msg` reads the subject git commits: it skips leading
    comment lines (`core.commentString`, then `core.commentChar`) and blank
    lines, so a `commit.template` no longer gets a valid subject rejected.
    It also accepts an unedited `git merge --squash` message.
  - `.githooks/pre-commit` runs `flutter analyze --no-pub` on its export
    unless a staged `pubspec.yaml` or `pubspec.lock` differs from the working
    tree. Before, every commit re-resolved dependencies.
  - `ci.yml` and `strip-smoke.yml` decide their scope with
    `git diff --no-renames`. A `.dart` file renamed to a `.md` under `docs/`
    no longer makes a PR count as docs-only.
  - `scripts/dev/audit_template.sh` falls back to `sha256sum`, and refuses to
    run when neither hash tool is installed. Before, it reported generated
    code as matching without hashing anything.
  - `setup_git_hooks.ps1` warns about hooks left in `.git/hooks`, as the
    `.sh` does.
  - The setup brick removes its placeholder from a CRLF checkout.

- **Docs corrections.**
  - `.env.example`: logging is on in every environment.
  - The upgrade guide uses `flutter pub add` to raise a constraint.
  - The onboarding layer diagram points data at domain.
  - The RASP recipe subscribes to `onThreatDetected` before calling
    `startProtection()`, so threats raised while it starts reach the listener.

- **`flutter analyze` stays clean on Riverpod 3.5.** Riverpod 3.5.0
  deprecates `ProviderContainer.exists`, and one test
  (`test/core/network/forced_logout_session_test.dart`) called it, so
  `flutter pub upgrade` left a tree that failed analyze on the deprecation
  info. The test now records built providers with a `ProviderObserver`.
  If you upgraded and hit the warning, take that test file again.

- **The pre-commit hook works in a pub workspace.** With the app as a member
  of a Dart pub workspace (a root `pubspec.yaml` with `workspace:`, the app
  with `resolution: workspace`), the hook refused every commit with
  "Dependencies are not resolved", and the `flutter pub get` it advised did
  not help: pub writes `package_config.json` only at the workspace root. The
  hook now finds the root through `.dart_tool/pub/workspace_ref.json`. If you
  copied the hook into your project, take `.githooks/pre-commit` again.

- **The Isar template's setup works.** Its second step, `flutter pub add
  --dev isar_generator`, failed version solving against `freezed` 4. The
  template and `docs/api/core/storage.md` now use the community-maintained
  `isar_community` packages, put collections in
  `lib/core/storage/collections/` with their generated code excluded from
  analysis (Isar's output fails `very_good_analysis`), and say that Isar 3
  runs on Android, iOS and desktop but not on the web. Nothing to change
  unless you started on the old steps; if you did, switch to the
  `isar_community*` packages.

- **Home links to the samples and can sign out.** The home screen listed
  nothing, so the tasks sample and the debug flags screen could be reached
  only by typing a URL on the web, and nothing signed out. Each feature now declares a
  `HomeDestination` beside its routes, `buildHomeDestinations` in
  `routes_registry.dart` lists them, and home renders them plus a sign-out
  action in the app bar. Sign-out goes through a new core seam,
  `signOutProvider`, which `authModuleOverrides` fills. If you added your own
  buttons to `HomeScreen`, move them into a `HomeDestination` (see
  `docs/api/examples/adding-features.md`, Step 4) or keep them; a container
  built without `authModuleOverrides` now throws on sign-out instead of doing
  nothing.

- **A remote feature-flag source now takes effect.** Overriding
  `featureFlagsRemoteDataSourceProvider` with your own remote source (Firebase
  Remote Config, LaunchDarkly, an endpoint of your own) had no effect: nothing
  initialized it, and the auto-disposed providers would have thrown the
  initialization away. The flag providers now live as long as the
  `ProviderContainer`, the first flag read initializes and fetches the remote
  once, and a remote that fails to initialize is logged as a warning while
  flags fall back to local values. Nothing to change in your code; if you
  worked around this by reading `featureFlagsInitializationProvider` yourself,
  that still works and is now redundant.

## [3.0.2] - 2026-11-01

Nothing to change in a project you have not set up yet. If you already ran
the setup brick, two leftovers are worth a minute: see the first and last
entries below.

### Fixed

- **The setup brick puts your app's name in the welcome sentence.** After
  `mason make flutter_starter_setup`, the home screen still said "Welcome to
  Flutter Starter with Clean Architecture!" in every locale; the brick now
  replaces every mention of the template name in the Dart and ARB sources,
  as the manual rename already did. A project already set up with the brick
  can fix it by hand: replace `Flutter Starter` in `lib/l10n/app_*.arb` and
  in the two tests that find the sentence (`test/main_test.dart`,
  `test/widget_test.dart`), then run `flutter gen-l10n`.
- **`flutter test` passes right after the setup brick.** With the samples
  kept and the rename not yet committed, two cases in
  `test/tooling/strip_rerun_test.dart` failed. Committing the rename already
  made them pass; nothing to change otherwise.
- **The setup brick no longer leaves `_mason_hook_only.md` behind.** Mason
  needs one template file, which the brick used to leave at the project root
  for you to delete. Its hook now deletes it when setup finishes. If yours is
  still there from an earlier setup, delete it.

## [3.0.1] - 2026-11-01

Nothing to change in your project. A new README for projects created from
the template, and one layout fix.

### Fixed

- **The home screen's welcome heading is centered on a phone.** It wrapped
  flush against the left screen edge; it is now centered and inset 24 px,
  like the hint under it.

### Documentation

- **The root README is a landing page.** It now opens with badges, a "Use
  this template" link and iOS Simulator screenshots, followed by "Why this
  starter", a quick start, a "What you get" table, tech stack, project
  structure and quality gates. "Using this template" lists the parts that
  describe the template rather than your app (badges, screenshots, "Why this
  starter", Support) so a new project can delete them; a project that already
  has its own README needs nothing.

## [3.0.0] - 2026-11-01

If your project was created from v2.0.0 or earlier, read every **Breaking**
entry below; each says what to change. Several concern release builds, which now
refuse to start misconfigured: an `https` `BASE_URL` and `API_SSL_FINGERPRINTS`
(or pinning turned off) are required for staging and production. Upgrade path:
`docs/guides/migration/upgrading-this-starter.md`.

### Breaking

- **A release build configured as `ENVIRONMENT=development` refuses to
  start.** `development` is the default and the value `.env.example` ships, so
  a release built from an unedited `.env` used to run with the debug routes
  registered, HTTP logging on and pinning off. It now opens on the startup
  failure screen instead (profile builds are not affected).
  **What you change:** build releases with `ENVIRONMENT=staging` or
  `production` - for example `--dart-define-from-file=.env.production`
  (`.env.production` and `.env.staging` are now git-ignored). `build.yml`'s
  manual input now defaults to `staging`, and `build_all.sh development`
  exits with an explanation.
- **`ENABLE_SSL_PINNING` accepts only `true`/`1`/`yes`/`on` and
  `false`/`0`/`no`/`off`** (any case). Any other value used to read as false
  and silently ship a release unpinned; it now keeps the default, and a
  release refuses to start on it, as do the build helpers. Check your `.env`
  copies and CI variables for another spelling.
- **`freerasp` is no longer a dependency; RASP is opt-in.** It linked a
  closed-source SDK and several Android permissions (`READ_GSERVICES`,
  `USE_BIOMETRIC`, SMS/call package queries, ...) into every release, even
  with RASP off. `FreeRaspServiceImpl` and its tests now ship as
  `.dart.template` files. If you bound `FreeRaspServiceImpl`, run
  `flutter pub add freerasp:8.2.4` and rename the three templates back to
  `.dart` (security implementation guide, section 7, step 1).
- **A staging or production release needs `API_SSL_FINGERPRINTS`.** Pinning
  is on there by default, and a release with pinning on and no fingerprints
  used to run unpinned in silence; it now refuses to start through the
  startup failure screen. Set your server's SHA-256 fingerprints, or
  `ENABLE_SSL_PINNING=false` to ship unpinned on purpose. `build_all.sh`,
  `build.yml` and the Android and iOS deploy templates now pass the value
  through `scripts/ci/ssl_pinning_defines.sh` and refuse to build without it:
  export `API_SSL_FINGERPRINTS` for `build_all.sh`, and set the repository
  variable `API_SSL_FINGERPRINTS` (or `build.yml`'s `ssl_fingerprints` input)
  for the workflows. The fastlane build and upload lanes take
  `ssl_fingerprints:<list>` (or `API_SSL_FINGERPRINTS`) and `ssl_pinning:false`
  the same way, and stop before building without either.
- **Configured `API_SSL_FINGERPRINTS` now pin in development too**, unless
  `ENABLE_SSL_PINNING=false`. **What you change:** if you set fingerprints in
  a development `.env` and debug through a proxy, add
  `ENABLE_SSL_PINNING=false` there.
- **Coverage now counts every library under `lib/`**, including files no test
  imports (`tool/coverage_helper.dart` generates a git-ignored test that
  imports them all, and the Quality gate, `coverage.yml` and
  `test_coverage.sh` run it before measuring). An untested file used to be
  missing from `lcov.info` and never lowered the total. **What you change:**
  if your total drops below `COVERAGE_MIN_TOTAL`, add tests or lower the
  floor deliberately.
- **`deploy-web.yml` fails until you fill in its deploy steps.** It used to go
  green while building and deploying nothing. **What you change:** fill in a
  deploy target, then delete the "Fail while nothing is deployed" step.
- **Re-run `./scripts/dev/setup_git_hooks.sh`** (or `.ps1`). It now points
  the repository's `core.hooksPath` at `.githooks/` instead of copying the
  hooks into `.git/hooks/`, which git ignores whenever `core.hooksPath` is set
  (globally, by husky-style setups). An older copy in `.git/hooks/` keeps
  running the old hooks until you do. It refuses, and says so, when the
  repository already points `core.hooksPath` somewhere else.

- **`AuthRemoteDataSource.logout` takes `{String? refreshToken}`** and posts
  it as `{"refresh_token": ...}`, so the server can revoke the session; it
  used to send nothing. **What you change:** add the parameter to your own
  `AuthRemoteDataSource` implementations and test fakes, and accept the body
  on your `/auth/logout` endpoint.
- **A staging or production release refuses a `BASE_URL` that is not
  `https`**, a relative or scheme-less value included: web and desktop do not
  block cleartext, so tokens would travel unencrypted. `build.yml` falls back
  to the https defaults per environment. **What you change:** use an `https`
  URL in release builds; `http://10.0.2.2` and `localhost` stay for
  development and debug builds.

### Security

- `AuthInterceptor` attaches the access token only to the API's own origin
  (judged on the URL dio actually sends). An absolute URL on another host -
  a presigned upload, a pagination link - no longer receives it, and that
  host's 401 no longer refreshes or ends the session.
- A 401 for a request sent under a session that has since ended (the user
  signed out, maybe someone else signed in) no longer refreshes the current
  user's tokens or replays the old request as them.
- `RawWebSocketClientImpl` opens its `wss://` handshake through the pinned
  `HttpClient` (`SslPinning.createHttpClient()`) when pinning is in effect.
- `PerformanceInterceptor` and the Firebase performance template record the
  request path redacted, as the logs do, so a `?token=` no longer reaches a
  trace attribute.
- `RawWebSocketClientImpl` no longer exposes the connect URL's token or
  userinfo: its log lines, the cancellation error and the error a failed
  handshake rethrows are built from `ApiLoggingInterceptor.redactUrl` (new),
  and an unparsable URL is reported redacted. The rethrown handshake error now
  names the inner error type instead of quoting dart:io's message.
- The default `NoOpRealtimeClient` prints only in debug builds, the URL
  redacted, and a sent payload's type rather than its content.
- `SecureTokenStore` applies its operations in the order they are issued. On
  web, flutter_secure_storage let a logout's clear land before a pending
  token write, leaving a live access token on a signed-out browser.
  `ITokenStore` now documents the ordering an implementation must keep; a
  custom store whose calls can complete out of order should queue them too.
  The queue is shared by every `SecureTokenStore` over one
  `SecureStorageService`, so components touching the tokens must use one
  service.
- `CacheInterceptor` no longer stores a response whose `Cache-Control` names
  `no-store`, `private` or `no-cache`, carries `Pragma: no-cache` or sets a
  cookie, and such a response evicts what an earlier one stored for that URL.
  Cache keys are a SHA-256 of the URL, so a token in a query string is no
  longer written to `shared_preferences`; indexed entries under the old
  verbatim keys are removed on the first request, with caching enabled or
  not.
- A `GET` whose query has a key the log redaction treats as a secret
  (`token`, `otp`, `signature`, ...) bypasses `CacheInterceptor` entirely, so
  its response body is not stored either. `ApiLoggingInterceptor.isSensitiveKey`
  is now public; both use it.
- `sig` (Azure SAS signature) and `auth` (Firebase REST ID token) are now
  sensitive keys: redacted from logs and kept out of the HTTP cache.
- `AuthRepositoryImpl.refreshToken()` checks the session before each of its
  two credential writes and before returning. A logout that landed during the
  access-token write used to leave the new refresh token on a signed-out
  device.

- `AuthRepositoryImpl.login()` and `register()` re-check the session before
  each credential write, so a logout during the round trip is no longer
  undone by the sign-in's later writes.
- `SecureTokenStore` reads strictly: a failed Keychain/Keystore read throws
  `CacheException` instead of reading as "no token", which signed the user
  out. A predecessor call that hangs no longer blocks every later token
  operation: the wait is bounded by `operationTimeout` (10 s).
  `SecureStorageService.clear()` is documented as unsuitable for sign-out.

- `SecureTokenStore`: a token write or delete that outlives the queue's wait
  bound and lands after a newer one (a refresh write landing after a
  sign-out's clear) is followed by a repair that puts the newer state back.
  A repair that fails three times is logged as a warning naming the key,
  never the value; reads of that key then answer from memory with the newer
  state, the next write (or, for a cleared key, the next delete) re-applies
  it, and a sign-out's clear never writes a token. `tokenStoreProvider`
  passes the app logger to the store.

- Log redaction and the HTTP cache's secret-query bypass treat more names
  as secrets: `access_key`, `app_key`, `client_key`, `hmac`, the Azure
  `subscription-key` and `x-functions-key`, `session_key`, `auth_key`,
  `master_key`, `license_key`, and exactly `bearer`, `sign`, `key` (Google
  APIs) and `access`/`refresh` (Django REST Framework SimpleJWT). `code` is a
  secret in a query string only (an OAuth code, an Azure Functions key); a
  body's `{"code": 404}` stays readable. A GET carrying any of these as a
  query parameter is no longer cached.
- `RawWebSocketClientImpl` refuses a realtime URL that is not `wss://` in a
  staging or production release, as `main()` refuses a non-`https`
  `BASE_URL`; a refused URL leaves a live connection alone.
- `scripts/ci/ssl_pinning_defines.sh` and the fastlane pinning helper
  validate `API_SSL_FINGERPRINTS` entries the way the app parses them: a
  space-separated fingerprint or one with a line break inside is refused
  instead of building a release that refuses every connection.

- `ApiLoggingInterceptor` passes a `RedactedDioException` to the logger and
  the error reporter instead of the `DioException`: the original's text ended
  with dart:io's `HttpException`, which quotes the full request URI. The
  logged `baseUrl`, `RetryInterceptor`'s lines and `PerformanceInterceptor`'s
  trace also go through `redactUrl`, which now trims leading whitespace, so an
  absolute URL's userinfo is removed everywhere.
- The HTTP cache records the sensitive-key rule version
  (`ApiLoggingInterceptor.sensitiveKeyRuleVersion`) and empties itself once
  when it changes, dropping responses cached for URLs a newer rule treats as
  secret. **On the first request after upgrading, the cache is emptied once.**
  If you change the key sets, bump the version (a test fails until you do).
- The startup refusal of a non-https `BASE_URL` shows the URL through
  `ApiLoggingInterceptor.redactUrl`, so userinfo and secret query values no
  longer reach the failure screen or the error reporter.
- In a staging or production release, the realtime client refuses a
  WebSocket handshake redirect that leaves TLS (`wss://` answering
  `302 -> http://`). A redirect that stays on TLS is still followed, pinned.
- `ImageCacheHelper`'s debug prints name an image URL through `redactUrl` and
  an error by its type, so presigned signatures and `?token=` values stay out
  of the console.
- `.gitignore` ignores `.env` and every `.env.*` except `.env.example`
  (`.env.dev`, `.env.prod`, `.env.test` used to be committable).
- `AppConfig.printConfig()` (debug builds) prints `BASE_URL` through
  `ApiLoggingInterceptor.redactUrl`, so userinfo and secret query values no
  longer reach the debug console.

### Fixed

- **`LoggingService` writes logs in profile and release builds.** It relied on
  the logger package's default filter, which drops every event once asserts
  are off, so the production file and console outputs received nothing.
- `ApiLoggingInterceptor.redactPath` no longer throws on a query key with
  malformed or non-UTF-8 percent-encoding (`%zz`, `%E9`) or raw non-ASCII;
  such a request used to fail in every build, because `PerformanceInterceptor`
  redacts every path. A key it cannot read has its value redacted.
- `build.yml`'s manual build defaults to `staging` and no longer offers
  `development`; `scripts/ci/build_all.sh development` exits with an
  explanation instead of building artifacts that refuse to start.
- The fastlane Appfiles and Fastfile comments name only options fastlane has
  (`json_key_data_raw`, `json_key`/`json_key_data`, `api_key_path`,
  `app_store_connect_api_key`); several commented lines failed with
  `NoMethodError` once uncommented. **If you uncommented** `json_key_data`,
  `api_key_id`, `api_issuer_id` or `default_track` in an Appfile, replace them
  as the comments now describe.

- **The release-signing refusal's `key.properties` template is valid.** It
  showed `storeFile=upload-keystore.jks   # relative to android/, or absolute`;
  `.properties` files have no trailing comments, so a pasted copy pointed at a
  keystore that does not exist. The note is now on its own `#` line.
  If your `android/key.properties` came from that template, remove the text
  after `storeFile`'s value.

- `AuthRepositoryImpl.refreshToken()` returns a failure
  (`INVALID_AUTH_RESPONSE`) for a refresh body it cannot parse, instead of
  letting a `TypeError` escape its `Result`; `AuthInterceptor` ends the
  session for it.
- `DioExceptionMapper` keeps an `AppException` an interceptor put in
  `DioException.error`, so it reaches the caller as itself instead of as
  `UNKNOWN_NETWORK_ERROR`. A custom `ITokenStore` that throws
  `CacheException` while the refresh call goes out now ends the session
  (documented and pinned by a test); the shipped store catches its own
  errors.
- `PaginationHelper`: a page requested before `reset()` no longer lands after
  it, mixing the old query's items into the new list.
- Feature flags: concurrent `setLocalOverride` calls no longer drop a key from
  the override index, which left that override active and unlisted after
  `clearAllLocalOverrides()`.
- `strip_sample_features.dart` refuses an unknown flag before deleting
  anything, and `--remove-bricks` also removes the test that imports them.
- The `feature_clean` brick validates its input in `pre_gen`, before anything
  is written.
- The pre-commit hook checks the staged content (exported to a temporary
  directory), not the working copy, and no longer rewrites files in place.
- `test_coverage.sh` rejects a non-numeric `--min`, and both it and
  `coverage.yml` fail on a coverage figure that is not a number instead of
  passing.
- The Quality gate runs the tests that read markdown on a docs-only pull
  request, and checks markdown links on every pull request, so renaming a
  file a document links to fails the gate.
- The fastlane upload lanes (`upload_internal`, `upload_alpha`, `upload_beta`,
  `upload_production`, `upload`, `upload_testflight`, `upload_appstore`,
  `release`) find the artifact they just built. They passed the upload action
  a path relative to `fastlane/`, which the action resolved from the project
  root, and failed with "Could not find aab/ipa file".
- `scripts/test/test_coverage.sh` removes the generated, git-ignored
  `test/coverage_helper_test.dart` when it exits. A copy left behind broke
  `flutter analyze`, `flutter test` and pre-push after the next rename under
  `lib/`. Delete any copy you already have.
- The pre-commit hook works with a relative `path:` dependency outside the
  repository (a monorepo's `../shared`). It now exports the staged content
  to a hidden `.<repo>-pre-commit.*` directory beside the repository instead
  of the system temp directory, and removes it afterwards.
- `git-hooks.yml` and `release-scripts.yml` also run on pull requests that
  touch their paths (template repository only, as before), so a broken hook
  or release script no longer merges green.

- Tasks: a stored task with a wrong-typed field, or an undecodable list,
  fails as a `CacheFailure` instead of escaping as a `TypeError` or reading
  as no tasks (which the next save overwrote). Toggling a task that is not
  stored returns `NotFoundFailure`; Delete is disabled while a toggle of the
  same task is pending.
- Startup: tapping Try again twice no longer runs two bootstraps at once;
  `bootstrap()` shares the one in flight and the button is disabled while it
  runs.
- fastlane: every lane accepts only `environment:staging` or `production`
  (trimmed, any case) and stops on anything else, which used to build a
  release that refuses to start. `get_version` accepts a pubspec version
  without `+build` (build number 1) and refuses a prerelease.

- The setup brick escapes `app_display_name` for each file it lands in (XML
  in the manifest and Info.plist, a quoted YAML string for
  `patrol.app_name`, a Ruby string in the Fastfiles), so `Salt & Pepper` no
  longer produces files that fail to parse. `pre_gen` refuses a blank name,
  control characters, `{`/`}` and a leading `@` or `?`.
- `tool/check_env_assets.dart` also flags `*.env`, `.env-*`, `.env_*` and
  `.envrc*` files, by name in the asset list or inside a declared directory.
- The accessibility test helpers can fail: `AccessibilityMatchers` match the
  node from `tester.getSemantics(finder)`, `AccessibilityTestHelpers.isEnabled`
  reads the enabled state correctly, and `verifyInteractiveElementsHaveLabels`
  runs Flutter's `labeledTapTargetGuideline`.
- `setup_brick_feature_rename_test` reads only tracked brick files, so a local
  `mason make` (which leaves compiled hooks) no longer fails it.

- Feature flags: a failed override write shows an error on the debug screen
  instead of the success message (`FeatureFlagsManager`'s override methods
  return the `Result`), and a failed flag listing shows the error and its
  retry instead of "no flags".
- Core utils: `ImageCacheHelper.preloadImage` without a context handles an
  already-cached image; `LazyLoader`, `LazyInitializer` and
  `DeferredImportLoader` retry a loader that threw synchronously;
  `DisposalTracker` runs every disposable and `super.dispose()` when one
  throws; `Throttler` measures time monotonically, so a backward clock step
  no longer suppresses calls.
- `tool/strip_sample_features.dart` can be re-run after a failure, ignores
  git-ignored files in its reference scan, and refuses to run outside the
  project root.
- Tests that run a Dart file use `dart --packages=...` instead of `dart run`,
  whose concurrent native-asset bundling crashed `dartdev` at random.

- `OptimizedListView` follows a `ScrollController` passed or swapped after its
  first build; `DateTimeExtensions.isYesterday`/`isTomorrow` count calendar
  days, so they are right across a daylight-saving change.
- `LocalizedFormatters.formatCurrency` without a currency code uses the
  currency of the locale's country (SAR for `ar_SA`, not Egyptian pounds).
- Log files are written to the app's cache directory instead of its
  documents (iCloud-backed on iOS, the shared `~/Documents` on desktop).
  Files written before stay in the old `logs/` directory.
- **`coverage.yml` no longer has a PR-comment step**, nor the
  `pull-requests: write` scope it needed. No trigger reached it as shipped;
  if you enabled `pull_request`, read the run's job summary or install the
  Codecov app for PR comments.
- `scripts/test/test_coverage.sh` compares percentages in awk, so a missing
  `bc` no longer turns a failing threshold into a pass, and
  `test_coverage.ps1` runs `tool/coverage_helper.dart` first and exits
  non-zero when tests fail.
- `scripts/ci/release.sh` refuses before changing anything when the release
  branch or tag already exists (also for a `version:` line with a trailing
  comment), and its summary claims a deploy only when a deploy workflow has
  a live `on: push: tags:` trigger.
- `scripts/dev/setup_ci.dart` exits 64 on an unknown flag, or a `--dir` with
  no path, and writes nothing (`--dryrun` used to write the workflows); `-h`
  and `--help` print the usage. `--dir=<path>` was never read and is now
  refused: pass `--dir <path>`.
- `scripts/dev/setup_git_hooks.sh` (and `.ps1`) works with the app in a
  subdirectory of a larger repository: `core.hooksPath` is set relative to
  the top, a failed check restores the previous value, and `pre-commit` and
  `pre-push` run in the app. It also names hooks in `.git/hooks` that stop
  running once `core.hooksPath` points at `.githooks/`.
- The `feature_clean` brick refuses a `class_name` that is not UpperCamelCase;
  the setup brick refuses a `package_name` that is already a dependency in
  `pubspec.lock`, before anything is written.
- `create_feature.ps1` cases identifiers with the invariant culture (a
  Turkish locale produced an invalid identifier).
- `tool/coverage_helper.dart` leaves out a library that imports or exports a
  web-only library, so one such library no longer fails the coverage run.
- Docs checks: a quoted `--dart-define="KEY=..."` is read, and the Android
  toolchain check ignores commented-out versions.
- **A sign-in waits for any logout still tearing down** - a user's logout
  (`AuthRepositoryImpl.logout`) or `AuthInterceptor`'s forced logout - so the
  teardown can no longer delete the credentials of the sign-in that followed
  it. `SessionGeneration` gains `trackTeardown` and `teardownsSettled`; the
  wait is bounded by `AuthRepositoryImpl.pendingLogoutLimit` (30 s), after
  which the sign-in fails with the new `AuthErrorCodes.signOutInProgress`. A
  sign-in also still invalidates the session synchronously, so a logout
  called right after it ends it.
- A forced logout that lands while a sign-in is waiting on it no longer
  stops that sign-in's spinner: `AuthNotifier.clearSession()` keeps
  `isLoading` while a `login`/`register` is in flight, so the button cannot
  start a second sign-in that cancels the first.
- `SecureTokenStore`: a read of a token key left stale after a failed repair,
  whose newer state is a delete, retries that delete (bounded, one retry per
  key at a time, never a write), so a signed-out app does not leave the late
  token for the next launch. The repair warning names every way a stale key
  is re-applied.
- Docs tooling: the test-path, `.env`-run, `--dart-define`, link/anchor,
  symbol and signature checks share one fence tracker (`tool/doc_fences.dart`):
  a fence closes only on its own character at least as long, so a ``` line
  inside a `~~~` or four-backtick block no longer flips them; a continued
  line never joins across a fence; a quoted or escaped `--dart-define` key is
  read; `/* */` and `!` comments are ignored by the Android toolchain check;
  string interpolations no longer hide declarations from `doc_symbols`.
- `check_docs` reports a malformed `<!-- symbol: -->` or `<!-- signature: -->`
  directive (it used to skip it), no longer counts an initializer, an
  expression body, a comment or a string as a declaration, and checks
  `CLAUDE.md`'s links, `flutter test` paths and `.env` runs.

### Documentation

- Getting started: the remove-the-demo steps name every file that uses the
  demo (including `AppConfig.hasBackend` and its test), so following them
  leaves `flutter analyze` and `flutter test` green.
- Storage migration guide: the migration test snippet stamps the store's
  version before `execute()`, so it passes as written.
- A pass over the guides: snippets that did not compile (API integration,
  testing, architecture overview, common tasks, customization) now do, and
  several are compiled by tests; stale `file:line` references were replaced
  by checked symbol markers; the error, storage, logging, network, i18n,
  coverage, upgrading, onboarding, ADR 0005 and CONTRIBUTING pages were
  corrected against the code.
- `docs/guides/security/implementation.md` and `docs/api/core/network.md`:
  a secret in a URL path segment is never redacted from logs or traces; put
  it in a header, the body, or a sensitively named query parameter.

- `docs/deployment/android-deployment.md`: the same `key.properties` example,
  fixed the same way.
- `docs/guides/security/implementation.md`, "Android Release Signing": no
  longer has you create `keystore.properties` or paste a replacement
  `build.gradle.kts`. It describes the signing and R8 setup that ships and
  says `android/app/proguard-rules.pro` is picked up automatically.
- `docs/guides/security/audit.md`: release signing is listed as implemented,
  not as an open CRITICAL.
- `docs/api/core/storage.md` gains a Web section: on Flutter web the tokens
  sit in `localStorage` with their AES key beside them, and what to do about
  it. The security audit lists it as an open item.
- Security guide: a web CSP that lets CanvasKit and fallback fonts load, with
  `X-Frame-Options`, `X-Content-Type-Options` and `Permissions-Policy` moved to
  server response headers (browsers ignore them in `<meta>`); an Android
  backup recipe covering Android 12+ `dataExtractionRules`; the RASP override
  added in `createAppContainer` instead of a second container that dropped
  `authModuleOverrides`.
- `api-integration.md`, the auth `providers.md` quotes and the retry-policy
  quote of `createAppContainer` match the code, and docs tests keep them so.
- Troubleshooting: `--dart-define` works on web, and a new configuration key
  goes into `DartDefines.values`.
- Performance work uses `--profile`; release examples include the keystore step
  and `ENVIRONMENT=production`.
- CONTRIBUTING says what the Quality gate runs for a markdown-only PR and what
  Docs check adds; `tool/README.md` says the same for each docs check.
- `adding-features.md` passes `--class_name`; getting started and the
  configuration guide say a `.env` or `--dart-define` change needs `flutter
  run` again; fork-and-customize names the setup brick's real variables.
- `scripts/README.md`, `bricks/README.md` and both brick READMEs describe
  `core.hooksPath`, every `scripts/test/` script and what each `pre_gen`
  checks.
- The coverage guides describe the job summary, not a PR comment.
- `docs/api/core/network.md`: where a mutual-TLS client certificate has to go
  for `ApiClient` and the release realtime handshake (pinning on, off, and
  through `HttpOverrides`).
- `docs/guides/security/implementation.md`: the Log Sanitization, Android
  Release Signing and R8 / ProGuard sections render again on GitHub (a nested
  fence had turned them into code).
- The coverage guides match the workflows (no figures the gates forbid, the
  Codecov upload that is active, coverage commands that run
  `coverage_helper.dart` first); `utils.md` lists `DateFormatter`'s ISO-8601
  pair and every validator; the i18n guide shows what `LocalizedFormatters`
  really prints per locale; ADR 0006 names symbols instead of line numbers;
  the touch-target snippet compiles and runs; the testing troubleshooting
  names Riverpod's real `No ProviderScope found`; only a no-op remote
  feature-flag source ships, and the READMEs say so.


## [2.0.0] - 2026-10-29

The first tagged release. If your project was created from the template before
this tag, every **Breaking** entry below may apply to it; each says what to
change. Upgrade path: `docs/guides/migration/upgrading-this-starter.md`.

### Breaking

- **Toolchain floor: Dart 3.13 / Flutter 3.47.** The locked dependencies
  (go_router 18, flutter_secure_storage 11, riverpod_generator 4, freezed 4)
  resolve only on Dart >= 3.13.0 and Flutter >= 3.47.0.
  **What you change:** `flutter upgrade` to the current stable before
  `flutter pub get`.

- **riverpod_generator 4, riverpod_annotation 4, Freezed 4.** Generated
  providers are no longer `const`, and Freezed no longer accepts `final` on a
  constructor parameter.
  **What you change:** declare provider aliases `final` instead of `const`
  (`final AuthNotifierProvider authNotifierProvider = authProvider;`), drop
  `final` from Freezed constructor parameters, then run
  `dart run build_runner build --delete-conflicting-outputs`.

- **Feature flags: `FeatureFlagsManager` moved into its slice.**
  `lib/core/feature_flags/feature_flags_manager.dart` is now
  `lib/features/feature_flags/domain/feature_flags_manager.dart`
  (`FeatureFlags` is now an `abstract final class`; its constructor was
  already private, so no outside code could instantiate it).
  **What you change:** update the import.

- **Routing: the auth redirect reads `SessionStatus`.** `app_router.dart` no
  longer imports the auth slice; it reads `sessionStatusProvider`
  (`restoring` / `signedIn` / `signedOut`), declared in
  `lib/core/routing/routes_registry.dart` and filled by
  `AuthSessionStatusNotifier` in `lib/features/auth/routing/auth_routes.dart`.
  **What you change:** if you replaced or removed the auth feature, point
  `sessionStatusProvider` at your own sign-in state (or return
  `SessionStatus.signedIn` to turn the login redirect off). If you edited the
  redirect, re-apply your change on top of the new one.

- **Secure storage: flutter_secure_storage 11.** On Android the plugin now
  uses AES-GCM with a Keystore-wrapped key, and `resetOnError` stays `true`:
  data it cannot decrypt is cleared rather than thrown.
  **What you change:** if your app shipped on flutter_secure_storage older
  than 10, release a build on 10 first so stored values migrate; otherwise
  users are signed out once.

- **dio 5.11: a new `DioExceptionType.transformTimeout`.** It maps to
  `NetworkException` with code `TRANSFORM_TIMEOUT`, localized as a timeout,
  and is not treated as a transport failure by the stale-cache fallback.
  **What you change:** add the case to any exhaustive `switch` over
  `DioExceptionType` in your own code.

- **go_router 18.** **What you change:** follow go_router's own 18.0 migration
  notes for any route code you added; the starter's routes needed none.

- **very_good_analysis 11.** New lints such as `async_return_with_no_await`
  apply to your code; `one_member_abstracts` left the set, so its `ignore`
  comments now trip `unnecessary_ignore`. The formatter stays on
  `trailing_commas: preserve` via `analysis_options.yaml`.
  **What you change:** run `flutter analyze` and fix what it reports
  (`dart fix --apply` handles most).

- **Auth: `AuthLocalDataSourceImpl` requires `tokenStore`.** See the entry
  below.

- **`pubspec.yaml` declares the SDK floor the lock needs:** `sdk: ^3.13.0`, `flutter: '>=3.47.0'` (was `sdk: '^3.8.0'`). The language version is now 3.13: `dart format` reformats some expressions differently, and three lints that ask for 3.13-only syntax (`unnecessary_type_name_in_constructor`, `empty_container_bodies`, `prefer_initializing_formals`) are disabled in `analysis_options.yaml`. Merge your `environment:` and run `dart format` once.
- **`scripts/ci/verify_action_pins.sh` is gone**; use `dart run tool/check_action_pins.dart --verify-tags`.
- **The pin check is stricter.** In a flow mapping `uses` must come last (`- {name: x, uses: owner/repo@<sha>} # vX.Y.Z`); the version comment must be a plain release tag; `container:`, `services.<name>.image` and `runs.image: docker://...` need `@sha256:<64 hex>`; a `uses: ./path` with no `action.yml` fails. Pin anything you added the same way.

### Added

- Offline demo sign-in: a debug build with no `BASE_URL` signs in with a demo
  account, so the app runs end to end before you have a backend.
- Error reporting: an `IErrorReporter` seam that `LoggingService` forwards
  errors to; uncaught Flutter and platform errors, and startup failures that
  `main()` catches, are reported through it.
- Dependabot for pub and GitHub Actions, with the code generation stack in
  its own group.
- Quality gate fails when total line coverage drops below 94%.
- `audit_template.sh` checks that committed generated code matches its sources
  (`AUDIT_SKIP_CODEGEN=1` skips it).

- **Action pins** workflow (`.github/workflows/action-pins.yml`, any PR touching `.github/`): **Action pins** resolves each pinned action's `# vX.Y.Z` tag through the GitHub API and fails when the SHA is not that release's commit (for example a commit that exists only in a fork); **Workflow lint** runs a checksum-verified actionlint (with shellcheck) over every workflow. Read-only `GITHUB_TOKEN`.
- `tool/check_action_pins.dart`: the offline pin check, YAML-parsed; follows local actions anywhere in the repository and matches file names case-insensitively.
- `test/tooling/sdk_floor_test.dart` (declared SDK floor vs lock) and `test/tooling/workflow_dispatch_inputs_test.dart` (no free-text dispatch input interpolated into `run:`).
- Fork guide section 6 and a security checklist item: turn on Dependabot alerts and security updates for your repository.

### Changed

- Every workflow action is pinned to a release commit SHA instead of a tag.
- Replays after a 401 refresh and retries keep `transformTimeout`,
  `followRedirects` and `maxRedirects`.
- A feature's `domain/` may not import Flutter UI libraries (enforced by
  `test/tooling/import_rules_test.dart`).
- `logging_examples.dart` moved from `lib/` to `examples/`.

### Removed

- The example screen that opened feature-flag overrides directly.

### Removed (earlier, unreleased until this tag)

- **BREAKING - Auth**: `AuthLocalDataSourceImpl` no longer accepts
  `SecureStorageService? secureStorageService`. `ITokenStore tokenStore` is now
  a required parameter, and the `ArgumentError` thrown when neither was supplied
  is gone with it - the analyzer reports the missing argument instead.

  **What an adopter has to change.** Only code that constructed the data source
  with the secure-storage form. Nothing in this repository's `lib/` did;
  `lib/features/auth/di/auth_providers.dart` has always passed `tokenStore:`.
  If you have:

  ```dart
  AuthLocalDataSourceImpl(
    storageService: storageService,
    secureStorageService: secureStorageService,
  );
  ```

  wrap the service in the adapter the constructor used to build for you:

  ```dart
  AuthLocalDataSourceImpl(
    storageService: storageService,
    tokenStore: SecureTokenStore(secureStorageService),
  );
  ```

  `SecureTokenStore` is `lib/core/storage/adapters/secure_token_store.dart` and
  is unchanged. Behaviour is identical - the old constructor built exactly this
  object. Any other `ITokenStore` implementation works too, which is the point
  of the parameter being typed on the contract.

### Fixed

- `build.yml` passes its `workflow_dispatch` inputs through `env:`; `base_url` was substituted into the script text and could run as code.
- Workflow `run:` scripts quote `$GITHUB_OUTPUT` / `$GITHUB_PATH` (actionlint clean).
- The setup brick's display name now reaches `tool/golden` too, so stripping after a Mason rename keeps your app title (scripts-smoke covers rename then strip).
- `routes_registry_test.dart` checks the auth and home routes by membership, so a feature route may sit anywhere in `buildAppRoutes`, after home included.

### Documentation

- Getting started: "Connecting Your Backend" - requests go to `BASE_URL` + `/v1` + path (`ApiEndpoints.apiVersion`, set it to `''` for an unversioned API), and the auth endpoints and keys the app expects; the clone step names its directory; build_runner is no longer a setup step; the config chain is described as it resolves (dart-defines, the `.env` among them, then defaults).
- Auth models reference: "Adapting the auth slice to an existing API", with a worked mapping from a flat `accessToken`/`refreshToken` response with an int id.
- "Adding a feature" starts from `create_feature.sh` and ends at a routed, tested screen.
- Android deployment: release signing, the refusal without `android/key.properties`, and the `-PallowUnsignedRelease=true` smoke build.
- Fork guide and brick READMEs put `~/.pub-cache/bin` on `PATH` before `mason`.
- Routing examples use routes every stripped tree has; `analysis_options.yaml` records why the three Dart 3.13 syntax lints stay off.

## [1.0.0+1] - Enterprise Starter V2.0 Upgrade

### Added
- **Security**: Implemented FreeRASP (Runtime Application Self-Protection) with threat detection for root/jailbreak, emulator, debugger, unofficial store, and tampering.
- **Security**: Added SSL/Certificate Pinning via custom Dio `IOHttpClientAdapter` and `sha256` fingerprints validation.
- **Networking**: Added `RetryInterceptor` with exponential backoff algorithm to automatically retry requests encountering transient failures (timeout, 5xx).
- **Architecture**: Enforced strict Clean Architecture boundaries with `core/contracts` and transport-agnostic `INetworkClient`.
- **Infrastructure**: Added `StorageMigrationService` to handle safe schema versioning across releases.
- **Testing**: Reached industry-leading coverage ratio (2.25:1) with over 2,216 passing tests.

### Changed
- **CI/CD**: Upgraded GitHub Actions pipelines to modern runner syntax (v4/v5 versions) to prevent deprecation issues. Added native `cache: true` optimization for `subosito/flutter-action`.
- **Performance**: Decoupled Firebase dependencies (`firebase_core`, `firebase_performance`, `firebase_remote_config`) into optional `.template` files, saving ~5-8MB base bundle size for users who do not require Firebase.
- **API Client**: Consolidated logging logic into a unified `ApiLoggingInterceptor`.
- **Error Handling**: Enhanced `result.dart` and `failures.dart` to support a cohesive `copyWith` pattern across typed domain failures.

### Removed
- **Redundant Code**: Excluded unneeded Firebase logic out of the standard compiler path to enforce a lightweight starter philosophy.
- **Obsolete Utilities**: Removed `logging_interceptor.dart` in favor of full `ApiLoggingInterceptor` integration.
