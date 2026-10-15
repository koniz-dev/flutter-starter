# Issue 290 - the 401 head replay re-checks the session after storing the token

Fix: `AuthInterceptor._handle401Error` checks `SessionGeneration.isCurrent`
again after `await _tokenStore.setAccessToken(newToken)`. If the generation is
stale, the request fails with its original 401 and is not replayed.
`_logoutUser()` is not called, and `refreshedToken` stays null, so the
`finally` drain rejects every queued request. This is the same exit as the
check that runs before the write.

Tests: group "the 401 head replay re-checks the session after storing the
token" in `test/core/network/api_client_interceptor_chain_test.dart`. It
assembles a real `ApiClient`, so the replay uses the production `retryDio`
that borrows the host transport. A `_GatedTokenStore` blocks `setAccessToken`
on a `Completer`.

| Criterion | Artifact | Result |
|---|---|---|
| 1. Logout during the token write: one transport hit, and the caller gets an exception | `criteria1-2.log` (fixed); `prefix-red.log` (same test on the unfixed `lib/`) | PASS. Before the fix the test fails with "Expected: AppException, Actual: null", meaning the caller succeeded. |
| 2. Normal path: the 200 reaches the caller, and the replay carries the refreshed token | `criteria1-2.log` | PASS. It also passed before the fix, so the new check does not break the happy path. |
| 3. `test/core/network` and `test/features/auth` still pass | `criterion3.log`; full suite in `tests.log` | PASS: 572 tests in those directories, 2851 in the whole suite. |

Gates: `format.log` reports 0 changed and `analyze.log` reports no issues.
`run_acceptance.sh 290` reported FAIL on one gate, acceptance goldens. Its
only failure is `forced_logout_acceptance_test` (koniz-dev/flutter-starter#288),
which already fails on `main`. The 13 PNGs are the repository's standing
goldens, byte-identical to `test/acceptance/goldens/`
(`goldens-checksums.txt`). The closing session opened all 13, and no
criterion rests on them.
