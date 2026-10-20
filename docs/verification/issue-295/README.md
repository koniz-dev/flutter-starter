# Issue 295 - a session switch during the token read stops the request

Fix: `AuthInterceptor.onRequest` now runs the stale-session check, factored
into `_rejectIfSessionEnded`, twice: once before `await
_tokenStore.getAccessToken()` and once after it. A request whose
`SessionGeneration` ended while the platform read was pending is rejected as a
`DioExceptionType.cancel` with `extra['retry'] = false`. That applies to first
sends and re-sends alike, so it never reaches the wire.

Tests: group "a session switch during the token read stops the request" in
`test/core/network/api_client_interceptor_chain_test.dart`. It assembles a
real `ApiClient`. `_SessionSwitchingTokenStore` advances the shared generation
and returns `USER-B` on the N-th read made by `AuthInterceptor.onRequest`.
Reads made by `CacheInterceptor` do not count; the store tells them apart
from the synchronous stack. Each test asserts `authReads`, so the switch is
proven to have fired.

| Criterion | Artifact | Result |
|---|---|---|
| 1. Switch during the first send's read: zero transport hits, and the caller gets an exception | `criteria1-3.log` (fixed); `prefix-red.log` (unfixed `lib/`) | PASS: `authorizations` is empty, and the caller gets `NetworkException(REQUEST_CANCELLED)`. Before the fix, "Actual: null" (the caller succeeded). |
| 2. Switch during a re-send's read (503 then 200): exactly one hit, and the caller gets an exception | same | PASS: `authorizations == ['Bearer USER-A']`. Before the fix, "Actual: null". |
| 3. No switch: the stored token is sent; network and auth suites pass, including "a retry is never sent under a different session" | `criteria1-3.log`, `criterion3-suites.log`, `tests.log` | PASS: `[USER-A, USER-A]` with status 200. 575 tests pass in `test/core/network` plus `test/features/auth`, 3 of 3 in the #289 group, and 2854 in the full suite. |

Gates: `format.log` reports 0 changed and `analyze.log` reports no issues.
`run_acceptance.sh 295` reported FAIL on one gate, acceptance goldens. Its
only failure is `forced_logout_acceptance_test` (koniz-dev/flutter-starter#288),
which already fails on `main`. The 13 PNGs are the repository's standing
goldens, byte-identical to `test/acceptance/goldens/`
(`goldens-checksums.txt`). The closing session opened all 13, and no
criterion rests on them.
