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
