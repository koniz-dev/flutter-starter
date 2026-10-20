# Issue 52 - acceptance evidence

`fix(auth): a failed remote logout leaves tokens and the session on the device`

Verified against `main` at the merge of PR #103
(`3c3f951d1417d2775aa80523e120488b6e86c8ed`).

## Artifacts

| File | What it is |
|---|---|
| `audit_template.log` | `./scripts/dev/audit_template.sh` on the merged tree, `exit: 0` (criterion 8) |
| `criterion-tests.log` | The four touched test files, expanded reporter, 82 tests, `exit: 0` |
| `criterion-7-pre-fix.log` | The **same** post-fix tests run against the **pre-fix** `lib/` (`git checkout 3c3f951^ -- lib/`). 14 failures: the new assertions are load-bearing |
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `./scripts/test/run_acceptance.sh 52` |
| `failed_logout_before_home.png` | Golden: the signed-in app on home, before the logout attempt |
| `failed_logout_after_login.png` | Golden: after a logout whose remote call threw, the login screen is laid out and an error line is rendered in the error colour |
| `goldens-checksums.txt` | `shasum -a 256` pairs for every PNG here against `test/acceptance/goldens/` |

## Criterion map

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | `clearCache()` / `clearAllTokens()` still run when the remote logout throws | PASS | `criterion-tests.log`: `logout should return failure when logout fails` (now `verify(clearCache)`), and `logout tears the local session down ... after a NetworkException / a 500 ServerException / a connection timeout / an Error`, which assert the real in-memory token store is empty afterwards |
| 2 | After a failed remote logout, `isAuthenticated()` is false and the token store is empty | PASS | `criterion-tests.log`, same four cases: `accessToken`/`refreshToken` null, cached user gone, `isAuthenticated()` false |
| 3 | The `Result` still reports the remote failure; precedence documented | PASS | Same four cases assert `result.isFailure`. Precedence pinned by `logout should report the local failure when the teardown also fails` - a failing teardown wins, documented on `AuthRepositoryImpl.logout()` |
| 4 | `AuthNotifier` clears `state.user`, so the router redirects to `/login` | PASS | `criterion-tests.log`: `logout should clear the user when the remote logout fails` and `router leaves home for login after the remote call fails` (asserts `AppRoutes.login` and `find.byType(LoginScreen)`); `failed_logout_before_home.png` -> `failed_logout_after_login.png` |
| 5 | `isAuthenticated()` consults the token store | PASS | `criterion-tests.log`: `isAuthenticated should return false when the token is gone but the user blob survives` and `... when the stored token is empty` |
| 6 | `AuthInterceptor._logoutUser()` clears the cached user too | PASS | `criterion-tests.log`: `forced logout cleanup clears the cached user as well as the tokens`, plus `still completes the handler when clearing the user throws` |
| 7 | The existing test is strengthened so it would fail against the old code | PASS | `criterion-7-pre-fix.log`: `logout should return failure when logout fails` is among the 14 failures against pre-fix `lib/` |
| 8 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit_template.log` (`exit: 0`, 2436 tests) |

## What these goldens do and do not prove

`flutter test` renders text with the Ahem font, so every glyph in a PNG is an
opaque block. The two logout goldens prove which screen was laid out, that an
error line is present in the error colour after the failed logout, and that the
home screen is gone. They prove **nothing** about wording - the screen identity
and the error string are asserted with `find.byType()` and an equality check on
`AuthState.error` in the test, not read off the image.

`failed_logout_before_home.png` is byte-identical to the repository's existing
`cold_start_restored_session.png`: both are the same home screen at the same
surface size. That is expected, not a copy-paste mistake.

## The other PNGs in this directory

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` here, so
`cold_start_no_session.png`, `cold_start_restored_session.png`,
`home_screen.png`, `startup_failure.png`, `theme_text_styles_dark.png` and
`theme_text_styles_light.png` are also present. **No criterion above rests on
them.** `goldens-checksums.txt` shows each one matches its counterpart under
`test/acceptance/goldens/`, so this run did not change them.

## Note on `criterion-7-pre-fix.log`

Two of the 14 entries are load failures rather than assertion failures:

- `auth_interceptor_test.dart` fails to compile against the pre-fix tree with
  `No named parameter with the name 'keyValueStore'` - that parameter is the
  criterion 6 change.
- `logout_teardown_test.dart` then reports `The Dart compiler exited
  unexpectedly`, a resident-compiler artifact following the first compile
  failure. Its tests still ran in the same log and failed on their assertions
  (`clears tokens and the cached user after ...`, `router leaves home for login
  ...`).
