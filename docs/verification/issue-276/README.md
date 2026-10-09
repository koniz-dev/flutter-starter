# Issue 276 - acceptance evidence

Fix: `53fc4274b6d` (PR #285). Its regression #286 was fixed in `1fcc3bcf9eb`
(PR #287) before this issue closed. Evidence was captured on `main` at
`59a824d`, which contains both.

| Criterion | Result | Artifact |
|---|---|---|
| 1. Assembled `ApiClient`, 401 with a failing refresh: caller gets `ServerException(statusCode: 401)` with the server's message | PASS | `criteria-1-3-mapped-401.log`, "criterion 1: a 401 whose refresh fails" (asserts type, status 401, message `Unauthorized`, code `TOKEN_EXPIRED`, no "Instance of") |
| 2. The same for the retry-exhausted, stale-generation and queued-request exits | PASS | `criteria-1-3-mapped-401.log`, the three "criterion 2" cases |
| 3. `ApiLoggingInterceptor.onError` logs the failed-refresh 401 exactly once | PASS | `criteria-1-3-mapped-401.log`, "criterion 3: the failed-refresh 401 is logged exactly once" |
| 4. `NetworkError.toString()` carries message, code and status | PASS | `criterion-4-network-error-tostring.log` (three cases) |
| 5. Forced-logout tests assert the concrete mapped type, not "some AppException" | PASS | `criterion-5-tightened-assertions.txt` (the `ServerException` / status 401 assertions now in both files) and `criterion-5-forced-logout-tests.log` (passing) |
| 6. `./scripts/dev/audit_template.sh` exits 0 | PASS | `criterion-6-audit_template.log` (exit 0) |

The red run is in `red-before-fix.log`. The new and tightened tests were run
against `caa6dbf`'s `auth_interceptor.dart` and `network_contracts.dart`, and
24 fail there.

## Correction to the issue body

The issue says `ErrorInterceptorHandler.reject` takes a
`callFollowingErrorInterceptor` flag. It does not; that flag belongs to the
request and response handlers. The fix uses `handler.next(...)`. The
correction was also posted as a comment on the issue.

## Acceptance goldens gate: FAIL, pre-existing, not caused by this change

The only failing test is `test/acceptance/forced_logout_acceptance_test.dart`,
which has failed the same way since #242.
`goldens-preexisting-failure-on-caa6dbf.log` shows it on `caa6dbf`, before
this change. The failure is filed as #288.

## Standing goldens

The 13 PNGs are the repository's standing goldens, and each is byte-identical
to the same-named file in `test/acceptance/goldens/` (`goldens-checksums.txt`).
No criterion rests on them. The closing session opened these exact files while
verifying #286, the same session, with identical checksums.
