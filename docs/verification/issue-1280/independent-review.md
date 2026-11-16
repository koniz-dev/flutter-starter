# Independent premerge network/security review: issue 1280 / PR 1294

Base: `285fd981076db8c1dddd4503d16f42ee2c9af8bd`.
Initial reviewed head: `e5ebcc11c0d9fe83016a18a710b7108138253bec`.
Intermediate reviewed head: `f7d5717463c6c572c38242732f2b241ef5340729`.
Final reviewed head: `968636aee8c293796d44cfdddae64239ee2cb276`.

Read the live issue acceptance criteria, actual two-file diff, maintainer process and CLAUDE.md. Review included malformed/encoded keys, userinfo, router prefixes, question marks within sensitive values, nested query-like shapes, idempotence, all callers, and cache admission/version coupling. No tracked files or outbound services were changed by this reviewer.

## Introduced finding, corrected on branch

**P2: unbounded quadratic suffix rescanning can freeze the calling isolate.** Initial head lines 352–359 called `_redactParameters` on the entire remaining fragment for every question mark, repeatedly splitting/copying almost the same text. Input `'/cb#section' + '?view=a' * N` is sufficient. Exact extracted static production methods were run with isolated SDK Dart 3.14:

| N | Characters | Base | Initial head | Revised head |
|---|---:|---:|---:|---:|
| 8,000 | 56,011 | 0.183 ms | 560.809 ms | 23.847 ms |
| 16,000 | 112,011 | 0.279 ms | 2,276.551 ms | 40.470 ms |
| 32,000 | 224,011 | 0.666 ms | 9,077.598 ms | 81.023 ms |

Each input is returned unchanged. The cost occurs synchronously, including when HTTP logging is disabled: `PerformanceInterceptor.onRequest` always invokes `redactUrl(options.path)`. Revised head scans non-overlapping query candidates per ampersand field; measured scaling is approximately linear. This resolves the introduced finding.

## Pre-existing hardening gap, not introduced against PR base

`/cb#/a=b?co?de=SECRET` and `/cb#/a=b?tok?en=SECRET` still contain SECRET at revised head and original base. The original PR loop incidentally redacted them; revised non-overlapping regex does not consider the whole punctuation-containing key. Existing key normalization drops punctuation, so co?de can normalize to code and tok?en to token. Exact base/initial/revised production code probes and output are in the raw log. This is outside the issue's two acceptance examples and is pre-existing against the PR base; owner was notified to decide whether to fix it here or file a separate hardening issue.

## Verification

All raw actual output: `1280-independent-tests.log` in this directory.

- Initial head focused tests: **141 passed** across fragment, malformed key, path query, userinfo, error object, redaction rules, cache version, performance path, raw WebSocket URL and uncaught error handler tests.
- Baseline mutation: copied base interceptor into an untracked work file and redirected only the fragment test's interceptor import to it. **Exactly the six newly added credential cases fail; the other 15 tests pass.** Added ordinary-fragment entries intentionally pass both implementations and are preservation controls, not regression witnesses.
- Revised head fragment suite and independent controls: **22 tests passed**, including one 90-input matrix covering 5 prefixes x 6 malformed/encoded/OAuth keys x 3 sensitive-value shapes. Every result removes userinfo and both secret markers and is idempotent.
- Independent benchmark scripts and split-key probes remain beside the raw log for reproduction. Scripts extract exact static production methods, removing only Flutter annotations/import dependencies.

Cache uses `options.uri.queryParametersAll` and unchanged shared key predicates, not `redactPath`/`redactUrl`; this PR does not tighten cache admission or change key sets. No rule version bump is required. Fragment-bearing cache behavior is pre-existing. Downstream redactor callers receive the same return type and continue to preserve ordinary route names and non-sensitive values. No additional introduced correctness/security defect found at revised head. Full host/CI gates are owned by the parent session and were not duplicated here.

## Final re-review: 968636aee8c293796d44cfdddae64239ee2cb276

**PASS: no remaining introduced defect found.** The owner also corrected the punctuation-split key gap on this branch, so the earlier intermediate-head gap is now resolved. Reviewed the actual incremental diff: cursor advances past each equals sign; each candidate key is decoded/normalized once by literal-question-separated parts; complete-key fragment rules and exact suffix rules preserve original key semantics without allocating growing suffixes. Encoded `%3F` does not create a query boundary. Malformed percent candidates fail closed. Whole sensitive values, including question-mark tails, are removed.

Final independent production test run: **27 tests passed** (25 fragment tests and 2 independent tests). Independent controls include **165 credential inputs** (5 prefixes x 11 key shapes x 3 value shapes), checking secret removal, userinfo removal, and idempotence; plus **7 exact suffix/encoded question/malformed-key controls**. Final baseline mutation produced **exactly 10 failures and 15 passes**: all ten added credential regressions fail the original base, while preservation/cache tests pass.

Additional exact-method performance probes, all returning unchanged inputs:

| Shape | 8k repetitions | 16k repetitions | 32k repetitions |
|---|---:|---:|---:|
| `/cb#/a=b` + repeated `?view=a` | 151.878 ms | 286.452 ms | 598.148 ms |
| Same prefix + repeated `?view`, no equals | 0.309 ms | 0.572 ms | 5.154 ms |
| Same prefix + repeated `?view`, ending `=public` | 121.665 ms | 64.553 ms | 128.035 ms |
| Same prefix + `?view=a`, repeated question tail with no further equals | 0.374 ms | 2.643 ms | 7.723 ms |

These are cold/JIT timings rather than a microbenchmark promise; long public-query cases demonstrate linear scaling rather than the initial quadratic scaling. The final helper has greater per-candidate overhead than the intermediate regex solution, but closes the normalized-key gap. The parent owns the full host/CI gates; this review did not duplicate the full suite.
