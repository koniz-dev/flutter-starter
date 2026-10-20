# Issue 289 - a retry is never sent under a different session

Fix: 3b290160df1 (PR #293). Evidence recorded on `main` at that commit.

| Criterion | Artifact | Result |
|---|---|---|
| 1. GET 503, session switched during hit 1: one transport hit, caller fails | `criteria-1-3-retry-session.log` (criterion 1) | PASS |
| 2. Same for a POST with `Idempotency-Key` | `criteria-1-3-retry-session.log` (criterion 2) | PASS |
| 3. Same-session 503 -> 200 retry still succeeds, both hits carry `Bearer USER-A` | `criteria-1-3-retry-session.log` (criterion 3) | PASS |
| 4. Existing `test/core/network/` (incl. `nothing is sent after a forced logout`) and `test/features/auth/` pass | `criterion-4-network-and-auth-tests.log` (+570, exit 0) | PASS |

Counterfactual: `red-before-fix.log` is the same group run on 6b4d9ea (before the fix). Criteria 1 and 2 fail with `Actual: <null>`, meaning the caller received a success after the session switched. That run used the looser `isA<AppException>()` matcher. The merged test asserts `NetworkException` with code `REQUEST_CANCELLED`.

Full gate: `audit_template.log` exits 0, with 2849 tests passing. The runner logs `format.log`, `analyze.log` and `tests.log` each exit 0.

`goldens.log` fails only `forced_logout_acceptance_test.dart`. That failure is pre-existing since #242 and tracked as koniz-dev/flutter-starter#288, and this change does not touch that test. The 13 PNGs are the repository's standing goldens, copied by the runner. Each one was opened. They prove nothing about this issue and are not cited. `goldens-checksums.txt` shows every copy matches its source in `test/acceptance/goldens/`.

Behaviour note, which fails closed: an anonymous request first sent before a login started, whose retry backoff spans that login, is now cancelled rather than re-sent with the new user's token.
