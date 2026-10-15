# Issue 384 - a 400 or 403 refresh rejection is tagged REFRESH_TOKEN_EXPIRED

Fix: `AuthRepositoryImpl._mapRefreshFailure` tags a `ServerException` whose
status is in `_deadRefreshTokenStatuses = {400, 401, 403}` with
`AuthErrorCodes.refreshTokenExpired`. Before the fix it tagged only 401.
Timeouts, connection errors, every 5xx, and 408 and 429 stay untagged.
The `AuthErrorCodes.refreshTokenExpired` doc comment now names the same three
statuses.

| Criterion | Artifact | Result |
|---|---|---|
| 1. Refresh fails with 400, 401 or 403: the failure is tagged `refreshTokenExpired` | `criteria1-2.log`; `prefix-red.log` (unfixed `lib/`) | PASS for all three. Before the fix, 400 and 403 failed, and only 401 passed. |
| 2. 408, 429, 500, 502, 503, 504 and `NetworkException` (RECEIVE_TIMEOUT, CONNECTION_ERROR) are not tagged | `criteria1-2.log` | PASS: 8 cases. |
| 3. `AuthNotifier.refreshToken()` logs out after a 400 | `criterion3.log`; `prefix-red.log` | PASS. The test goes through the real `RefreshTokenUseCase` and `AuthRepositoryImpl` with a remote that throws `ServerException(400, invalid_grant)`, and verifies the logout use case is called once. Before the fix it was never called. |
| 4. The doc comment lists the dead statuses and why 408 and 429 are excluded | `criterion4-doc.txt` | PASS |

Gates: `format.log` reports 0 changed, `analyze.log` reports no issues, and
`tests.log` reports 2866 passed. `run_acceptance.sh 384` reported FAIL on one
gate, acceptance goldens. Its only failure is `forced_logout_acceptance_test`
(koniz-dev/flutter-starter#288), which already fails on `main`. The 13 PNGs
are the repository's standing goldens, byte-identical to
`test/acceptance/goldens/` (`goldens-checksums.txt`). The closing session
opened all 13, and no criterion rests on them.

This issue unblocks koniz-dev/flutter-starter#303.
