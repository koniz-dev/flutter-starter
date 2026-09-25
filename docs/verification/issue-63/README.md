# Acceptance evidence - issue #63

`fix(core): validators accept malformed emails, date parsing is lenient and
timezone-lossy, and a perf mixin re-runs failed operations`

Verified against the merged change on `main`: PR #131, squash commit
`3191e91d35a769f55ba59aadd45d862f0b025817`.

Produced by `./scripts/test/run_acceptance.sh 63` (exit 0) plus the
per-criterion runs listed below. Each `criterion-*.log` is a `PASS`/`FAIL`
list of every test in that scope, generated from
`flutter test --reporter=json`, because the expanded reporter rewrites a
single terminal line and loses almost every test name when redirected.

## Criterion map

| # | Criterion | Result | Artifact and the line that proves it |
|---|---|---|---|
| 1 | `isValidEmail` rejects each malformed address in the table and accepts each valid one; the test at `validators_test.dart:46-65` is corrected | PASS | `criterion-1-2-validators.log` - 42 table-driven rows, e.g. `SUCCESS Validators isValidEmail rejects <user@example..com> - empty DNS label`, `... rejects <.user@example.com> - leading dot in the local part`, `... accepts <user@example.xn--p1ai> - punycode TLD`. `criterion-corrected-assertions.log` shows the five removed `expect(..., isTrue)` lines for the malformed inputs |
| 2 | `isStrongPassword` behaviour and doc agree; special-character decision stated; registration decision stated | PASS | `criterion-1-2-validators.log` - `SUCCESS Validators isStrongPassword accepts every non-alphanumeric as the special character` and `... doc comment and behaviour agree: no special char means false`. Decisions are in the `isStrongPassword` and `isValidPassword` doc comments in `lib/core/utils/validators.dart` |
| 3 | `parseDate('2024-02-30')` and `parseDate('2024-13-01')` return `null` | PASS | `criterion-3-4-dates.log` - `SUCCESS DateFormatter parseDate rejects out-of-range calendar fields instead of rolling over` (asserts both, plus `2023-02-29`, `2024-04-31`, `2024-00-10`, `2024-01-32`) |
| 4 | A UTC `DateTime` survives a format/parse round trip without shifting; explicit ISO-8601/UTC pair added | PASS | `criterion-3-4-dates.log` - `SUCCESS DateFormatter timezone round trip a UTC DateTime survives the ISO-8601 round trip unshifted`, `... formatIso8601 always emits a UTC instant ending in Z`, `... parseIso8601 normalises an explicit offset to UTC` |
| 5 | `JsonLogFormatter` emits an offset-bearing timestamp | PASS | `criterion-5-6-logging.log` - `SUCCESS FileLogOutput JsonLogFormatter emits an offset-bearing UTC timestamp` (decodes the JSON, asserts the `Z` suffix and `DateTime.parse(...).isUtc`) |
| 6 | A log emitted during rotation does not throw and no generation is lost; `clearLogs()` closes the sink it replaces; logs before file init are not dropped | PASS | `criterion-5-6-logging.log` - `SUCCESS FileLogOutput sink lifecycle (real temp directory) a log emitted during rotation does not throw, and is kept`, `... two concurrent rotations do not discard a generation`, `... clearLogs closes the sink it replaces` (awaits `IOSink.done` on the replaced sink), `... lines emitted before init resolves are not dropped`, `... the pending buffer is bounded`. These run against a real temp directory via a mocked `plugins.flutter.io/path_provider` channel, so they assert file contents rather than `greaterThanOrEqualTo(0)` |
| 7 | `measureDataSave`/`measureOperation` never execute the wrapped operation twice; counter closure asserts 1 | PASS | `criterion-7-8-9-10-performance.log` - `SUCCESS PerformanceRepositoryMixin measureDataSave never executes the wrapped operation twice` (the exact test the criterion asks for: a closure that increments and throws, asserting the counter is 1), plus `... runs the operation exactly once on failure`, `... instrumentation failure propagates instead of re-running the operation` (counter 0), and the same three for `PerformanceUseCaseMixin` |
| 8 | A failed operation stops the trace it started | PASS | `criterion-7-8-9-10-performance.log` - `SUCCESS PerformanceRepositoryMixin measureRepositoryOperation error` and `SUCCESS PerformanceUseCaseMixin measureUseCaseOperation error`, both now verifying `startSync()` and `stopSync()` were each called once. `criterion-corrected-assertions.log` shows the removed assertion that checked only `startTrace` |
| 9 | `_sanitizePath` collapses a UUID beginning with a digit to `:uuid` | PASS | `criterion-7-8-9-10-performance.log` - `SUCCESS PerformanceUtils measureApiCall sanitizes /users/550e8400-e29b-41d4-a716-446655440000 to api_get_/users/:uuid` (digit-leading, the ~62% case), plus `/users/f47ac10b-...`, `/users/550e8400-.../orders`, and the non-regression rows for `/users/123` and `/api/v1/user-profile-settings` |
| 10 | The performance screen mixin works via its documented wiring, or the doc is corrected | PASS | `criterion-7-8-9-10-performance.log` - `SUCCESS PerformanceScreenWrapper the documented setter wiring actually starts a trace` (a subclass assigning `performanceService` from its own `initState`, exactly as the setter's doc describes) and `... the trace starts exactly once across rebuilds`. Both wirings are now documented on the mixin |
| 11 | Each smaller item is fixed or explicitly deferred with a reason | PASS | `criterion-11-smaller-items.log` - 397 tests. Per item: `SUCCESS LazyLoader caches a legitimately null value without throwing`; `SUCCESS PaginationHelper config plumbing a 0-indexed API starts at page 0, not page 1`, `... reset returns to the configured initial page`, `... pageSize is readable`, `... an error is cleared by the next successful page`, `SUCCESS PaginationState.copyWith clearError drops an error that error: null cannot`, `SUCCESS PaginationScrollExtension a list that fits on screen counts as at the end`; `SUCCESS AppException.toString carries the type and the message`; `SUCCESS ExceptionToFailureMapper unmapped AppException subclasses an unknown AppException keeps its message and code`; `SUCCESS Result equality two Success values with equal data are equal`; `SUCCESS ImageCacheHelper preloadImage reports failure when given a context`; `SUCCESS FeatureFlagsManager getFlags should fall back to per-key defaults when repository fails`; `SUCCESS ProviderDisposal does not touch the global image cache on dispose`; `SUCCESS JsonHelper non-finite and non-Exception failures getInt returns null for a non-finite number` and `... getListOf returns null when the converter raises a TypeError`. `CrashlyticsOutput accepts fatal logs` is in `criterion-5-6-logging.log`. Two items are **deferred with a reason**, both recorded here: `JsonHelper.getDouble` still returns `double.infinity` for `1e999` (a representable double that throws nothing, unlike `getInt`), and `ProviderLifecycleManager.clearCaches` remains a documented placeholder because Riverpod exposes no cache-clearing API |
| 12 | A decision is recorded on the dead-utility question, and acted on | PASS | `docs/architecture/design-decisions.md`, section "Utilities with no sample call site" (problem statement, decision, rejected alternatives, what was done, when to reconsider). `criterion-11-12-call-sites.log` reproduces the call-site survey the decision rests on. Acted on: defects fixed with regression tests, buggy assertions corrected, and the harmful dead code deleted (`ProviderDisposal.dispose` no longer clears the global image cache; `registerProviderSubscription` and `WidgetRef.watchWithDisposal` are gone, removing the only two `// ignore: argument_type_not_assignable` comments in `lib/`). Wiring the survivors into the tasks sample is filed separately as #147, since it lands in `epic:feature-tasks` |
| 13 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit_template.log` - `No issues found!` from `flutter analyze` and `All tests passed!` at 2585 tests; `format.log`, `analyze.log`, `tests.log` from the acceptance runner |

## The standing goldens prove nothing here

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into this
directory. All eight were opened and inspected by the closing session: they show
the login screen, the home screen, the light and dark theme text-style
harnesses, a failed-logout error state, and the startup-failure screen. Nothing
this issue changed is visual - validators, date formatting, log output and the
performance mixins have no rendered surface - so **no criterion above rests on a
screenshot.**

`goldens-checksums.txt` is `shasum -a 256` over
`test/acceptance/goldens/*.png` and `docs/verification/issue-63/*.png`, sorted.
Every copied file's digest matches a committed golden's digest exactly (there
are six distinct digests across the eight files, because
`cold_start_no_session` / `cold_start_stale_user_no_token` and
`cold_start_restored_session` / `failed_logout_before_home` are pairwise
identical renders). The run left the goldens untouched; there is no golden
regression to explain.

The usual caveat still applies and is worth restating: `flutter test` renders
text with the Ahem font, so every glyph in these PNGs is an opaque block. They
could not confirm wording even for an issue that was about wording.

## Files

| File | What it is |
|---|---|
| `README.md` | This criterion map |
| `audit_template.log` | Full `./scripts/dev/audit_template.sh` run, exit 0 |
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | Acceptance runner gates |
| `criterion-1-2-validators.log` | 94 tests: email table and password composition |
| `criterion-3-4-dates.log` | 22 tests: strict parsing and the UTC round trip |
| `criterion-5-6-logging.log` | 159 tests: JSON timestamp, rotation, clearLogs, pre-init buffering, Crashlytics fatal |
| `criterion-7-8-9-10-performance.log` | 92 tests: single execution, trace stop, path sanitisation, screen-mixin wiring |
| `criterion-11-smaller-items.log` | 397 tests: the smaller items |
| `criterion-corrected-assertions.log` | The removed assertions that previously pinned each defect as correct |
| `criterion-11-12-call-sites.log` | Call-site survey behind the dead-utility decision, and the check that no persisted timestamp flows through `DateFormatter` (the offset-less timestamp it does turn up in `TaskModel` is filed as #146) |
| `goldens-checksums.txt` | Digests proving the copied PNGs are the repository's unchanged goldens |
| `*.png` | The eight standing goldens. Inspected, cited for nothing |

## Two things this run turned up, neither a criterion

**Test-only fix included in this evidence PR.** Two regression tests added by
PR #131 landed inside the wrong `group(...)`: the `LazyLoader` null-cache test
reported under `LazyInitializer`, and the `AppException.toString` group nested
inside `Edge Cases`. Both assertions were always correct and always ran; only
the reported names were misleading. They are moved to their proper groups here,
which is why `criterion-11-smaller-items.log` reads
`SUCCESS LazyLoader caches a legitimately null value without throwing`. No
behaviour, and no `lib/` file, changed.

**An unrelated flake, filed rather than fixed.** Two full-suite runs during
verification failed in `test/core/network/`, both timeout-shaped
(`did not complete`) rather than assertion-shaped:
`auth_interceptor_refresh_queue_test.dart` once, and 30 cases in
`api_client_interceptor_chain_test.dart` once. Each file passes on its own -
`api_client_interceptor_chain_test.dart` runs 22 tests green in 23s - and the
immediately following full-suite run was green at 2585 tests, which is the
`audit_template.log` committed here. Nothing in this change touches
`lib/core/network/`. Filed as #145 under `epic:testing`; not fixed here.

## Not verified here

- **Real-device and real-font behaviour.** Nothing in this change has a visual
  or device-dependent surface, so this is a statement of scope rather than a
  gap.
- **`FileLogOutput` under real app lifecycle pressure.** The rotation and
  pre-init tests drive a real temp directory on the host VM. They do not prove
  behaviour under an Android/iOS document directory, a full disk, or a process
  killed mid-rotation.
- **The performance mixins against a real Firebase Performance backend.**
  `firebase_performance_service.dart.template` is not compiled into the app;
  the tests drive `IPerformanceService` through mocks. What is proven is that
  the mixin calls `startSync`/`stopSync` and executes the operation once.
