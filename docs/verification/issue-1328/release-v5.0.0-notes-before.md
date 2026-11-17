
### Breaking

- [Utility validation contracts](https://github.com/koniz-dev/flutter-starter/issues/1284): phone validation now requires 7–15 digits with optional initial + and space/hyphen separators; URL validation requires http/https/ftp/ws/wss and valid ASCII DNS/punycode or IP hosts and unsigned ports. Convert international domains to punycode and apply a separate policy for other URI schemes. JsonHelper.getInt now returns null for fractions, overflow or target rounding; callers needing truncation must validate range and truncate explicitly, and large identifiers should remain strings.

- Forks with custom iOS AppDelegate code must follow the UIScene lifecycle migration: conform to FlutterImplicitEngineDelegate and register plugins through the engine bridge in didInitializeImplicitFlutterEngine. Preserve custom native lifecycle behavior when merging; see docs/deployment/ios-deployment.md. Existing deployment targets and signing settings are unchanged.

- Custom widgets, themes or design-token adapters using design-library types must switch their Material/Cupertino imports to material_ui/cupertino_ui so their public types match the starter. Retain the l10n.yaml header and its delegate adapters when regenerating translations; update relative imports if relocating generated output. See the standalone UI section of upgrading-this-starter.md.

- **Partially persisting custom refresh callbacks must store the complete credential pair.** A callback that writes only the refresh token and returns an unpersisted access token now cancels without replay or teardown. Persist both access and refresh before returning, or mutate neither and return the access token. Ambiguous ABA states also cancel safely; see the [network callback migration](https://github.com/koniz-dev/flutter-starter/blob/main/docs/api/core/network.md).

- **Custom ITokenStore implementations require versioned adoption methods.** Add credentialRevision, getAccessTokenSnapshot and setAccessTokenIfCurrent with shared mutation revisions and synchronous conditional reservation; an asynchronous get/set fallback is unsafe. See the [storage API migration](https://github.com/koniz-dev/flutter-starter/blob/main/docs/api/core/storage.md#versioned-refresh-result-adoption).

- **Custom auth datasource logout signature changes.** Custom `AuthRemoteDataSource` implementations must accept the new optional `accessToken` argument on `logout` and use it as the Authorization header when their server requires it.

- **`IAuthController` and `authControllerProvider` are removed.** Nothing in the starter read them; the UI uses the generated `authProvider`. If your code typed against `IAuthController`, `AuthStateSnapshot` or `ControllerStateSnapshot`, or read `authControllerProvider` or `AuthNotifier.snapshot`, read `authProvider` / `authProvider.notifier` instead, or declare the contract in your own code. `AuthNotifier`'s methods are unchanged.

- **Staging and production builds need your API URL.** `scripts/ci/build_all.sh` and the manual `build.yml` workflow no longer fall back to `https://api.example.com`. Set `BASE_URL_STAGING` / `BASE_URL_PRODUCTION` in the environment (for `build.yml`: its `base_url` input, or a repository variable or secret of those names). A missing, non-https or `example.com` URL is refused before anything is built; copy `scripts/ci/release_base_url.sh` together with the updated script and workflow.

- **Android builds on Flutter 3.50 need the newer toolchain.** Flutter 3.50 refuses Android Gradle Plugin below 9.1.1 and Kotlin below 2.4.10. Copy the three versions: Gradle 9.5.0 in `android/gradle/wrapper/gradle-wrapper.properties`, AGP 9.3.1 and Kotlin 2.4.20 in `android/settings.gradle.kts`. `tool/check_android_toolchain.dart` now enforces these floors; they also build on Flutter 3.47.

- **Dependency floors moved after v4.0.0.** `patrol` ^4.11.0 needs `patrol_cli` 4.9.0 (reinstall the CLI); `equatable` ^3.0.0 removes `EquatableMixin`, so write `with Equatable` where your code said `with EquatableMixin`; `go_router` ^18.1.4, `material_ui` ^1.11.0 and the code generators (`build_runner` 2.17.1, `build` 5.0.0) are routine: run `flutter pub get` and regenerate.

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

