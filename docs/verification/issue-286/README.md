# Issue 286 - acceptance evidence

Fix: `1fcc3bcf9eb` (PR #287), on top of `53fc4274b6d` (PR #285, issue #276),
which introduced the regression. Evidence was captured on `main` at `1fcc3bc`.

| Criterion | Result | Artifact |
|---|---|---|
| 1. 401, refresh ok, replay 503, then 200 on a GET: transport hit exactly twice, caller gets an exception | PASS | `criteria-1-4-no-resend.log`, case "a replay failing with 503 is not re-sent" |
| 2. No request after `SessionGeneration` advanced carries `Authorization` | PASS | same cases: exactly two hits, both recorded with their headers before the logout; generation asserted advanced, store asserted empty |
| 3. Same with the replay failing on `receiveTimeout` and `connectionError` | PASS | `criteria-1-4-no-resend.log`, the two `DioExceptionType` cases |
| 4. A retry re-sent with no token stored carries no leftover `Authorization` | PASS | `criteria-1-4-no-resend.log`, "a retry made after the token is gone ...". A caller-attached header is still kept ("an Authorization header the caller attached is kept") |
| 5. Existing network tests still pass, including the #276 mapping and logging | PASS | `criterion-5-existing-network-tests.log` (87 tests, exit 0) and `tests.log` (full suite, 2846 tests, exit 0) |

The red run is in `criteria-1-4-red-before-fix.log`. The same group was run
against `main@53fc427`'s `auth_interceptor.dart`, and all four regression cases
fail there. In the three replay cases the caller received a success; in the
retry case the header was `Bearer expired-access-token`.

## Acceptance goldens gate: FAIL, pre-existing, not caused by this change

`run_acceptance.sh 286` reports one failing gate, "acceptance goldens". The
only failing test is `test/acceptance/forced_logout_acceptance_test.dart`,
which builds its container without `authModuleOverrides`. It has failed the
same way since #242. `goldens-preexisting-failure-on-caa6dbf.log` shows it on
`caa6dbf`, before #285 and #287. The failure is filed as #288.

## Standing goldens

The 13 PNGs here are the repository's standing goldens, copied by the script.
`goldens-checksums.txt` pairs each with `test/acceptance/goldens/`, and every
file is byte-identical to the golden of the same name. No criterion rests on
them. All 13 were opened by the closing session; text renders as Ahem blocks,
so nothing about wording is claimed.
