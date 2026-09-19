# Acceptance evidence - issue #78

`fix(security): ApiLoggingInterceptor still logs secrets - string bodies bypass
_sanitizeJson entirely, query parameters are never sanitized, and the header set
omits proxy-authorization`

Change merged to `main` as `d188c79` (PR #112). Evidence produced on `main` at
that commit.

## Artifacts

| File | What it is |
|---|---|
| `interceptor_tests.log` | targeted run of `test/core/network/interceptors/api_logging_interceptor_test.dart` on the fixed code: 33 tests, all pass |
| `counterfactual.log` | the same test file run against the **pre-fix** interceptor (`origin/main` before `d188c79`): `+21 -12`, twelve of the thirteen new tests fail |
| `audit_template.log` | `./scripts/dev/audit_template.sh` on merged `main`: format check, analyze, 2456 tests, exit 0 |
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `./scripts/test/run_acceptance.sh 78` gate logs, all pass |
| `docs_check.log` | `dart run tool/check_docs.dart`: 516 links, 0 broken; 0 emoji |
| `tests-run1-unrelated-flake.log` | first acceptance run, kept deliberately - see "The one failed run" below |
| `goldens-checksums.txt` | SHA-256 of every PNG here paired with its source under `test/acceptance/goldens/` |
| `*.png` (8 files) | the repository's standing acceptance goldens, copied in automatically |

## The screenshots prove nothing about this issue

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into the
evidence directory regardless of what the issue is about. This issue is about
what a logging interceptor writes into a `LoggingService` context map - it has
no visual surface at all. All eight PNGs were opened and inspected; they show
the home screen, the login screen, a restored session, a startup failure, a
failed logout and the light/dark text-style sheets, none of which touches HTTP
logging.

`goldens-checksums.txt` shows every evidence PNG hashing identically to its
`test/acceptance/goldens/` source, so this run did not change them. **No
criterion below rests on a screenshot.** (`cold_start_restored_session.png` and
`failed_logout_before_home.png` share a hash because the two goldens are
byte-identical in the repository; that predates this change.)

## The one failed run

The first `run_acceptance.sh 78` reported FAIL on the `flutter test` gate, with
a single failure in
`test/core/network/interceptors/auth_interceptor_refresh_queue_test.dart`
(`three concurrent 401s with a failing refresh`, expected `refreshCalls == 1`,
got `3`). That log is kept as `tests-run1-unrelated-flake.log` rather than
deleted.

It is unrelated to this change and is a timing flake, not a regression:

- the test file never references `ApiLoggingInterceptor` or `LoggingService`;
- it passes in isolation, and passed in the two subsequent full-suite runs
  (`tests.log`, `audit_template.log`);
- it passed in CI on PR #112 (Quality gate, run 35443799503);
- the mechanism is visible in the test: it waits a fixed
  `Duration(milliseconds: 50)` for two follow-up requests to land while a
  refresh is in flight. Under full-suite parallel load that window can be
  missed, and all three requests then start their own refresh.

Filed separately as koniz-dev/flutter-starter#121 rather than fixed here.

## Criteria

| # | Criterion | Artifact | Verdict |
|---|---|---|---|
| 1 | A `String` body containing JSON is sanitized; no `hunter2`, no raw encoded string, `***REDACTED***` present | `interceptor_tests.log`, test `sanitizes a pre-encoded JSON string body field by field`; fails pre-fix in `counterfactual.log` | PASS |
| 2 | A non-JSON `String` body is not corrupted and not dropped, and a test pins which | `interceptor_tests.log`, tests `redacts a form-encoded string body wholesale`, `redacts a plain-text string body wholesale`, `redacts a bare JSON scalar string body`. **Pinned behavior: redacted wholesale**, and the `body` key survives so the log shows a body existed and was withheld | PASS |
| 3 | Query parameters sanitized by the same rules; `abc123` gone, `page` still present | `interceptor_tests.log`, tests `sanitizes query parameters by the same rules as bodies` and `sanitizes the query parameters conventionally used to carry credentials`; fails pre-fix in `counterfactual.log` | PASS |
| 4 | `proxy-authorization`, `x-auth-token`, `x-refresh-token`, `api-key` in `_sensitiveHeaderKeys`, each driven through `RequestOptions` in mixed casing | `interceptor_tests.log`, test `redacts proxy-authorization, x-auth-token, x-refresh-token and api-key in mixed casing` (plus `x-csrf-token`); fails pre-fix in `counterfactual.log` | PASS |
| 5 | Error path: `DioException` with 401, string request body with a password, string response body with a refresh token; no secret in the captured `error` context; must fail pre-fix | `interceptor_tests.log`, tests `leaves no secret in the error context for a failed login...` and `...when the bodies are not JSON`. `counterfactual.log` shows the first one failing pre-fix with the full leaked context printed: `requestBody: {"email":"a@b.c","password":"hunter2"}` | PASS |
| 6 | `docs/api/core/network.md` updated | `docs/api/core/network.md`, section `What gets redacted, and how it is decided`, added in `d188c79`; `docs_check.log` confirms links and emoji checks pass | PASS |
| 7 | `./scripts/dev/audit_template.sh` exits 0 | `audit_template.log`, last line `All tests passed!`, exit 0 | PASS |

## The sanitization rule, and its cost

Redaction is decided by **key name only, never by value shape**. Value-shape
matching (a JWT-looking regex, say) catches tokens under unexpected key names,
but it also redacts legitimate base64 payloads, hashes and opaque ids, and makes
the redaction set impossible to predict by reading the code.

The cost is real and is pinned by a test rather than hidden: a secret carried
under a key name that is not listed is still logged. `interceptor_tests.log`
includes `decides by key name, not value shape, so a token under an unlisted key
is still logged`, which asserts that a JWT under the key `blob` survives. An
OAuth `code` query parameter is likewise not redacted, and
`docs/api/core/network.md` says so by name.
