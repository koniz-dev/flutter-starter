# Issue 77 - acceptance evidence

`fix(security): HTTP cache stores authenticated GET responses in plaintext
shared_preferences, keyed only by URI and never cleared on logout`

Change merged to `main` as `92b996c` (PR #102).

## Precondition, stated honestly

No sample code in this repository issues an authenticated `GET` through
`ApiClient`. `auth_remote_datasource.dart` only POSTs and tasks is local-only.
The defect was **latent here** and fires on the first authenticated `GET` a
consumer of this template writes with the documented `apiClient.get(...)` API.
Nothing below claims a live exploit was observed in the shipped sample app.

## One correction to the filed analysis

The issue states that every authenticated 200 `GET` was written to
`shared_preferences`. The counterfactual run (`counterfactual.log`) shows that
is not what happened in this assembly.

dio runs `onResponse` in registration order as well as `onRequest`
(`dio-5.9.2/lib/src/dio_mixin.dart:471-475` and `495-500`), and
`response.requestOptions` is the **same** `RequestOptions` instance
`AuthInterceptor` mutated. So by the time the old header sniff ran on the
response leg, the `Authorization` header **was** present and the write was
skipped. Pre-fix, three of the nine new tests still passed, including
`an authenticated GET is never written to storage`.

What was genuinely live pre-fix:

- **The read leg.** `CacheInterceptor.onRequest` at index 1 saw no
  `Authorization` header, so a body cached during an anonymous session was
  handed straight back to a later authenticated request through
  `handler.resolve(...)` - no network call, no auth check. Proven failing
  pre-fix: `an anonymously cached body is not replayed to an authenticated
  request` returned `{'motd': 'anonymous'}` where `{'motd': 'authenticated'}`
  was expected.
- **The write leg when options do not carry the header** - a direct
  `onResponse` call, or any future reordering. Proven failing pre-fix: `the
  interceptor bypasses the cache for a request with no Authorization header at
  all when the token store holds a credential` wrote
  `http_cache_/users/me_{}: {"secret":"a"}`.
- **Nothing ever cleared the cache.** Both logout cases failed pre-fix with a
  fully populated store.

## Per-criterion result

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | Authenticated `GET` is not cached; assembled chain + seeded `ITokenStore` + fake `HttpClientAdapter`; nothing written to `StorageService` | PASS | `cache_policy_tests.log` - `an authenticated GET is never written to storage` (asserts the whole in-memory store `isEmpty`) and `a repeat authenticated GET always goes to the network, never to cache` (`adapter.hits == 2`, distinct bodies) |
| 2 | Cause fixed, not worked around; bypass no longer depends on a header another interceptor has not added | PASS | `cache_policy_tests.log` - `CacheInterceptor still precedes AuthInterceptor, so the guard must not be header-derived` asserts the concrete type order `[CacheInterceptor, AuthInterceptor, RetryInterceptor, ErrorInterceptor]`, that `CacheInterceptor` still comes first, and that the authenticated `GET` is still not cached. `the interceptor bypasses the cache for a request with no Authorization header at all when the token store holds a credential` drives the interceptor with provably headerless options; `counterfactual.log` shows it failing against the header-sniff implementation |
| 3 | Still-cached responses are keyed per identity, or not stored in `shared_preferences` | PASS | `cache_policy_tests.log` - `a second identity never sees the first identity's cached body` (same path under `token-a` then `token-b`, `adapter.hits == 2`, bodies differ) and `an anonymously cached body is not replayed to an authenticated request`. Taken via the "not stored" branch: no authenticated response is written at all, so there is exactly one cache identity (anonymous) |
| 4 | Logout clears the HTTP cache; `clearCache()` has a real implementation with a test proving entries are removed | PASS | `cache_policy_tests.log` - `a cached body is dropped by the logout path and the next identical GET goes to the network` drives the real `AuthRepositoryImpl.logout()` and asserts the store is empty, then `adapter.hits` goes 1 -> 2. `clearCache removes every entry it wrote, including timestamps`, plus the unit cases `should remove every indexed entry, its timestamp and the index itself` and `should be a no-op when nothing was cached` |
| 5 | `docs/api/core/network.md` states what is cached, where it is stored, and that authenticated responses are excluded | PASS | New `## CacheInterceptor` section in `docs/api/core/network.md` (what is cached / where it is stored / lifetime / configuration), plus the updated Overview bullet, `ApiClient` Properties list and Configuration bullet. `docs_check.log` - links, anchors and emoji gate passes |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit_template.log` - `All tests passed!`, exit 0. Also `format.log`, `analyze.log`, `tests.log` (2422 passed) from `run_acceptance.sh` |

## Counterfactual

`counterfactual.log` is a real run with the fix backed out in two places and
nothing else changed:

- `_hasSessionCredential()` replaced by `return false` (header sniff only);
- `clearCache()` body replaced by a comment (the original empty `try`).

Result: `+5 -4`. The four failures are the four listed in the correction above.
The five passes are explained by the response-leg accident, which is the reason
this log is included rather than summarised.

A positive control (`an anonymous GET is still cached`, `adapter.hits == 1` on
the second call) is in the same suite, so the "nothing was written" assertions
cannot pass vacuously.

## Screenshots

`run_acceptance.sh` copies the repository's standing acceptance goldens. They
are **not** evidence for any criterion here - every criterion in #77 is
headless HTTP-layer behaviour with no UI surface, so **no criterion above
cites a screenshot**. They were opened and inspected anyway, and are included
to show the change did not break app assembly: each renders normally, with no
overflow stripes and no error widget.

`goldens-checksums.txt` pairs each copied PNG with its source under
`test/acceptance/goldens/`. All six pairs match, so this run did not change
any golden and there is no regression hiding behind the copies.

| File | What it shows |
|---|---|
| `home_screen.png` | Home screen, light theme, blue app bar with two action blocks and a trailing icon; body text blocks and a centred row of four short blocks. Normal render |
| `cold_start_no_session.png` | Cold start with no stored session: login screen, two outlined text fields and a filled primary button, plus a row of link blocks. Normal render |
| `cold_start_restored_session.png` | Cold start with a restored session: home screen instead of login, same layout as `home_screen.png` at the larger surface. Normal render |
| `startup_failure.png` | Startup-failure screen, light-pink background, centred icon, message blocks and a purple retry button. Normal render |
| `theme_text_styles_light.png` | Text-style specimen, light theme: dark glyph blocks on a near-white background, blue outlined button |
| `theme_text_styles_dark.png` | Text-style specimen, dark theme: light glyph blocks on a near-black background, filled blue button |

Per `CLAUDE.md`: `flutter test` renders text with the Ahem font, so every glyph
is an opaque block. None of these images can confirm wording, and none is
claimed to.

## Not verified here - tier 3

On-device inspection of `/data/data/<pkg>/shared_prefs/*.xml` (Android) and the
`NSUserDefaults` plist (iOS), and extraction from an unencrypted device backup.
That requires a real device and is tier 3 per `CLAUDE.md`. It is **not an
acceptance criterion of #77**, so it does not block closing this issue; it is
handed off separately so the claim is eventually observed rather than inferred.

Its security weight is much reduced by this fix: post-fix nothing authenticated
reaches that store at all, so what remains to confirm is only that *anonymous*
cached bodies land there in plaintext, as the docs now state.

## Files

| File | Contents |
|---|---|
| `cache_policy_tests.log` | The 9 new `api_client_cache_policy_test.dart` cases, the updated `cache_interceptor_test.dart` unit cases, and `api_client_interceptor_chain_test.dart` (the #46 and #88 guards, untouched by this change) - 59 tests, all passing |
| `counterfactual.log` | The same suite against the two backed-out defects: `+5 -4` |
| `audit_template.log` | `./scripts/dev/audit_template.sh`, exit 0 |
| `docs_check.log` | `dart run tool/check_docs.dart` - 500 links, 0 broken; 0 emoji lines |
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `run_acceptance.sh` gate logs |
| `*.png` | Standing acceptance goldens, described above |
| `goldens-checksums.txt` | SHA-256 of each copied PNG beside its `test/acceptance/goldens/` source; all six pairs match |
