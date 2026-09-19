# Verification evidence - issue #53

`fix(testing): ten tests treat their own assertion failure as a pass, and 24
assert only expect(true, isTrue)`

Verified against merged `main`, commit `08cad8d` (PR #111).

## Per-criterion result

| # | Criterion | Result | Artifact |
|---|---|---|---|
| 1 | No test wraps assertions in a `catch` that treats `TestFailure` as a pass; throwing is asserted with `throwsA`/`expectLater` | PASS | `criterion-1-no-swallowed-assertions.log` |
| 2 | `expect(true, isTrue)` is no longer the sole assertion of any test or branch | PASS | `criterion-2-no-vacuous-expect.log` |
| 3 | The rewritten `storageInitializationProvider` tests fail when the implementation is gutted | PASS | `criterion-3-gutted-provider.log` |
| 4 | A host-VM test covers the SSL-pinning branch: adapter installed for pinned vs unpinned, and a fingerprint mismatch rejected | PASS (wiring only, see below) | `criterion-4-ssl-pinning.log` |
| 5 | `UiKeys.loginSubmit` / `registerSubmit` / `homeContent` asserted under plain `flutter test`; removing a `key:` fails the default suite | PASS | `criterion-5-uikeys-mutation.log`, `tests.log` |
| 6 | The `.template` no longer ships `expect(true, isTrue)` (was 14) | PASS | `criterion-6-template.log` |
| 7 | `./scripts/dev/audit_template.sh` exits 0 and the suite still passes | PASS | `audit_template.log` (exit 0, 2443 tests) |

## What is deliberately not claimed

- **Criterion 4 is wiring, not TLS.** The tests assert which
  `HttpClientAdapter` an `ApiClient` installs, that only the pinned policy sets
  the `createHttpClient` hook, and what the installed fingerprint check answers
  for a matching and a mismatched certificate. A real TLS handshake against a
  server presenting a bad certificate is tier 3 and was not run.
- **The eight PNGs in this directory prove nothing about this issue.**
  `run_acceptance.sh` copies every standing golden under
  `test/acceptance/goldens/` into the evidence directory regardless of what the
  issue is about. Each was opened and each is byte-identical to the
  repository's committed golden - see `goldens-checksums.txt`, where every
  evidence PNG shares a hash with its `test/acceptance/goldens/` twin. They are
  cited for no criterion.

## Defect exposed and filed, not fixed

Making the migration-failure test honest surfaced a real `lib/` defect, filed
as **koniz-dev/flutter-starter#101** (`type:bug`, `epic:core-storage`,
`priority:P1`):

Riverpod 3 retries any provider failure that is not an `Error`
(`ProviderContainer.defaultRetry`). `MigrationExecutionException implements
Exception`, so on the bare `ProviderContainer()` that `main()` builds, `await
container.read(storageInitializationProvider.future)` **never completes** -
measured at over 120 s with the migration body having run exactly once, versus
26 ms on a container with `retry: (_, _) => null`. The `try/on Object catch`
guard in `main()` that exists to show `StartupFailureApp` therefore never
fires: a user whose storage migration fails gets a process that never reaches
`runApp` at all.

Per the scope rule for this issue the defect was not fixed here. The test opts
out of retry and carries a `TODO(koniz-dev)` pointing at #101, with a comment
stating exactly what production does differently
(`test/core/di/providers_test.dart`, "surfaces a migration failure to the
caller").

## Files

| File | What it is |
|---|---|
| `audit_template.log` | `./scripts/dev/audit_template.sh` on merged main, exit 0 |
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | the four `run_acceptance.sh` gates |
| `criterion-1-no-swallowed-assertions.log` | grep plus a site-by-site accounting of every remaining `catch` |
| `criterion-2-no-vacuous-expect.log` | grep; the three remaining matches are comment prose |
| `criterion-3-gutted-provider.log` | mutation run: provider body replaced with `async {}` |
| `criterion-4-ssl-pinning.log` | `ssl_pinning_test.dart` output, with the scope limit stated |
| `criterion-5-uikeys-mutation.log` | two mutation runs: `homeContent` and `loginSubmit` keys removed |
| `criterion-6-template.log` | template occurrence count and what replaced it |
| `goldens-checksums.txt` | proves the eight PNGs are unchanged standing goldens |
| `*.png` | standing goldens copied by the harness; evidence for nothing here |
