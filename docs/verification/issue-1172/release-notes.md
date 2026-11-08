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
