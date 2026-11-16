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

# Postmerge QA/security review: issue 1280 / PR 1294

**PASS.** Reviewed merged main `1cb05ae13b6946bc6c12e0304ab63c3dfbaf0252`. `git diff 968636aee8c293796d44cfdddae64239ee2cb276..1cb05ae13b6946bc6c12e0304ab63c3dfbaf0252 --stat` is empty, confirming whole-tree parity with the independently accepted head. Working checkout was clean. Re-read the exact base-to-main two-file diff and the live issue spec.

## Mechanism and acceptance evidence

Ran actual production fragment tests and the retained independent final probe against merged main using isolated Flutter 3.50/Dart 3.14: **27 passed, exit 0** (25 fragment tests + 2 independent tests). Actual raw output is `1280-postmerge-review-tests.log`.

- AC1: both exact reported nested fragment shapes remove SECRET. Existing OAuth/router/userinfo-sensitive-value behavior, malformed/encoded keys, nested question marks, punctuation-split sensitive keys, public fields and exact suffix boundaries all pass. Independent matrix exercises 165 credential inputs (5 prefixes x 11 keys x 3 sensitive value shapes), checking removal, userinfo removal and idempotence, plus 7 boundary/malformed controls.
- AC2: reviewed evidence-worktree `docs/verification/issue-1280/format.log` (636 files, 0 changes, exit 0), `analyze.log` (no issues, exit 0), `tests.log` (4555 passed / 14 skipped, exit 0). Inspected work-file `1280-quality-final-tail.log`: CI actually ran 4554 tests / 16 skipped, coverage 96.71% against 94% minimum, and reports no tracked file changed. Inspected `1280-ci-current.json`: Quality gate and all five Strip checks SUCCESS for the accepted final head. Inspected `1280-root-inspection.md`, including its final-head addendum correcting intermediate implementation/timing descriptions.

The host and CI counts above are distinct actual runs; no full suite was duplicated during this postmerge review. Parent session owns the remaining G2 repository audits and additional caller probes. No screenshot/native/live-server proof is needed for this string-redaction mechanism and no such claim is made.

## Source/security assessment

The merged implementation preserves the first pass over complete sensitive values before nested query inspection. Its cursor advances past each equals sign and candidate raw keys are decoded/normalized by literal-question-separated parts. Fragment matches cover the complete normalized key; fixed exact-rule suffix comparisons handle punctuation-split exact keys without rescanning growing suffixes. Encoded question marks do not invent router boundaries. The earlier quadratic scan and intermediate punctuation-key gap are both resolved; independent premerge timings and mutation evidence remain in `1280-independent-review.md` / `1280-independent-tests.log`. Ten new credential regression cases were demonstrated to fail original base; preservation tests pass both versions.

Cache admission calls unchanged shared key predicates and parses the request query rather than invoking this fragment redactor; no cache rule/version change is required. No additional defect or risk was found in the merged diff. No tracked edits or outbound mutations were performed by this reviewer.

## REST/refs verification

Read-only REST issue and PR responses retained as `1280-postmerge-live.json` and `1280-postmerge-pr.json`. At inspection, issue 1280 remains open with exactly `status:in-progress`, sole assignee `koniz-dev`, and expected type/epic/priority labels. PR 1294 is merged to main with merge commit `1cb05ae13b6946bc6c12e0304ab63c3dfbaf0252`, accepted head `968636aee8c293796d44cfdddae64239ee2cb276`. The merge commit message contains `Refs koniz-dev/flutter-starter#1280`, with no autoclosing keyword. Closing remains the parent session's evidence/G2 responsibility.

