# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
