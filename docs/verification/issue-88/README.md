# Issue 88 - RetryInterceptor replays non-idempotent methods

Verification evidence for koniz-dev/flutter-starter#88, against the merged fix
on `main` (PR #96, commit `7b5c4da`), verified at `0ea4550`.

## Provenance

The fix merged with CI green, but the session that wrote it was terminated by
an API rate limit before it ran acceptance verification. This evidence was
produced afterwards by the orchestrating session, in a clean detached worktree
at `origin/main` - not in the implementer's tree.

## Criterion to artifact

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | A `POST` failing 503 reaches the transport once | PASS | `retry-idempotency-tests.log` - *a POST that fails with 503 reaches the transport once* |
| 2 | Same for `PUT`/`PATCH`/`DELETE`, and for `sendTimeout`/`receiveTimeout` as well as 5xx, parameterised | PASS | `retry-idempotency-tests.log` - 16 cases, each named `<METHOD> failing with <503\|500\|sendTimeout\|receiveTimeout> reaches the transport once` |
| 3 | A `GET` failing 503 is still retried 1 + `maxRetries`; #46's reachability guard survives, now using `GET` | PASS | `retry-idempotency-tests.log` - *retries a 503 through the assembled client (1 original + 3 retries) and still surfaces a domain ServerException*; the guard is `api_client_interceptor_chain_test.dart:237`, `apiClient.get('/tasks')` then `expect(adapter.hits, 4)` |
| 4 | Opt-in is explicit, per-request, defaults off, both paths tested | PASS | `retry-idempotency-tests.log` - *an Idempotency-Key header opts a POST back into retry through the ApiClient facade* (opt-in) against the 16 default-path cases (default off) |
| 5 | `docs/api/core/network.md` states which methods, how many times, on which error types, and how to opt in | PASS | `docs/api/core/network.md:15,185,340,358-368,376-398` |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit_template.log` - `AUDIT_EXIT=0`, `+2407 ~5: All tests passed!` |

## On the PNGs in this directory

`run_acceptance.sh` copies the repository's standing acceptance goldens into
every evidence directory automatically. All six here
(`home_screen`, `cold_start_no_session`, `cold_start_restored_session`,
`theme_text_styles_dark`, `theme_text_styles_light`, `startup_failure`) were
confirmed **byte-identical** (SHA-256) to their committed masters under
`test/acceptance/goldens/`.

They are therefore render-regression checks only: they show this change broke
no existing screen. **No criterion above rests on them**, and none could - this
issue is entirely about transport hit counts and documentation, and
`flutter test` renders text with Ahem, so a golden cannot show wording.

## Criterion 3, stated precisely

The risk this issue carried was that #46's regression guard pinned the *bug*:
it asserted `apiClient.post('/tasks', ...)` then `expect(adapter.hits, 4)`, so a
naive fix would have deleted the test that proves `ErrorInterceptor` is last.
It was rewritten to `GET`, not removed. Both properties now hold simultaneously:
retry is still reachable through the assembled chain, and `POST` is no longer
replayed.

## Not covered here

Per the issue's own "Not in scope": the stranded-handler and unpinned-replay
defects are #59, and the cache and logging sinks are #77 and #78.
