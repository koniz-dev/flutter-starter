# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-10-28

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
