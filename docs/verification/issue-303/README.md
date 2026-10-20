# Issue 303 - a transient refresh failure no longer forces a logout

Fix: `AuthInterceptor._handle401Error` asks `_endsSession(failure)` before it
tears a session down. The rule fails closed. Only a `NetworkFailure`, or an
untagged `ServerFailure` (408, 429, 5xx, since #384 tags 400, 401 and 403),
leaves the session alone. In that case:

- nothing is torn down and nothing is replayed;
- queued requests are rejected;
- the caller gets a `NetworkException` saying "Could not refresh the session
  (...)", instead of a 401 telling them to sign in again.

These still force the full logout:

- `REFRESH_TOKEN_EXPIRED` on any failure type;
- `NO_TOKEN_REFRESHER`;
- an untagged auth or unknown failure.

`AuthInterceptor.refreshTokenExpiredCode` mirrors
`AuthErrorCodes.refreshTokenExpired`, which core cannot import (#221). A test
pins the two together.

Tests: group "a transient refresh failure leaves the session alone (#303)" in
`test/core/network/forced_logout_cache_test.dart`. It runs on the fully seeded
signed-in world: an assembled `ApiClient`, an anonymous cached body, a cached
user blob, both tokens, and a counting `sessionSink`.

| Criterion | Artifact | Result |
|---|---|---|
| 1. `NetworkFailure(RECEIVE_TIMEOUT)` on a 401: token store, user blob and HTTP cache untouched, sink not called, caller gets an exception | `criteria1-3.log`; `prefix-red.log` (unfixed) | PASS: the device state after the call deep-equals the state before it, the sink count is 0, and the caller gets a `NetworkException` carrying the refresh failure's message. On the unfixed code the state was `{'keyValueStore': {}, 'accessToken': null, 'refreshToken': null}`, i.e. everything was wiped. |
| 2. The same for a `ServerFailure` (503) | same | PASS. Unfixed: the same wipe. |
| 3. `REFRESH_TOKEN_EXPIRED` still forces the full teardown, and the existing `forced_logout_*` tests stay green | `criteria1-3.log`, `criterion3-forced-logout-suites.log` | PASS: tokens are null, the cache is empty, the user blob is gone, and the sink is called once. All 17 tests in `forced_logout_cache_test.dart` plus `forced_logout_session_test.dart` pass, including the untagged-failure ones. |
| 4. `docs/api/core/network.md` "Forced logout" states which refresh failures end the session | `criterion4-doc.txt` | PASS: a table of refresh result, session outcome and what the caller gets. |

Gates: `format.log` reports 0 changed, `analyze.log` reports no issues, and
`tests.log` reports 2870 passed. `run_acceptance.sh 303` reported FAIL on one
gate, acceptance goldens. Its only failure is `forced_logout_acceptance_test`
(koniz-dev/flutter-starter#288), which already fails on `main`. The 13 PNGs
are the repository's standing goldens, byte-identical to
`test/acceptance/goldens/` (`goldens-checksums.txt`). The closing session
opened all 13, and no criterion rests on them.
