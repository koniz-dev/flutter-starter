# Independent pre-merge review: issue 1266 / PR 1277

Reviewer: fresh subagent, no implementer verdict supplied. Read `CLAUDE.md`, maintainer `process.md` (pre-merge review and G1b), issue `1266-live.json`, and the actual four-file diff from base `dbea2426a5866533d01a06bb7dc1c73e821b1c8a` to initial head `4a8018f02c956c61b0af205fe9547091eae6903a`. No tracked files or GitHub objects mutated. Scoped SDK probes use the Dart executable under `W/sdk-350/flutter/bin`; the owner runs full host/CI and actual Mason integration separately.

## Review findings

No introduced behavior defect identified in the initial diff. The refusal occurs after existing input validation and before any post-generation mutation. It handles a renamed package, Android namespace/applicationId, iOS app and test ids, macOS id, and Linux id. Missing platform files are skipped, so removing unused platforms does not prevent first setup. Paths resolve from the output working directory, consistent with the existing post hook, including a nested monorepo project; the guard does not depend on the Git root. A non-default app/test target id in an existing platform causes conservative refusal rather than a half-rename. Default identifiers match the repository's actual files.

The two logging edits condition both the write and success message on changed content. Replacing the package/id with the existing value prints no success line; changing it prints the line. The refusal text points to the manual path and explicitly requires adapting template defaults to current ids; the guide's new paragraph makes the one-time setup contract clear.

The original new test has a coverage gap: its negative `Renamed`/`Updated` assertions run only pre_gen, which cannot emit the changed post_gen messages. Both post_gen edits can be reverted while those assertions remain green. This was reported to the owner, who is adding a direct changed/no-op helper regression test and a counterfactual. Its three customized fixtures do distinguish the pre_gen fix from base; the fresh case remains passing on both revisions as expected. It does not itself perform two Mason CLI runs, so the owner's actual first-run/second-run probe is necessary evidence for the acceptance criterion.

## Dormant workflow assessment

`scripts-smoke.yml` is manual by design. Its setup-brick job runs actual Mason with non-default answers, analyzes and tests the renamed tree, generates a feature afterward, and strips after rename. It catches first-run changes and tests broken by import rewriting that a plain host gate misses. It does not exercise a second invocation; it also cannot catch reverted no-op log behavior without a targeted helper test. The owner has dispatched this workflow and separately driven actual first/second Mason CLI integration. This reviewer did not rerun the full suite.

## Independent probes

Raw output: `1266-independent-tests.log`. Runner: `1266-review-probes.py`. Scratch directories are unique below W. The runner hashes every fixture file before and after each pre_gen invocation, so no-write results include untracked fixture files as well as source content. Final runtime results and exact revised-head binding will be appended after completion.

Runtime results completed: removed platforms and nested monorepo output accepted (exit 0); macOS-only customization, Linux-only customization, missing root, and invalid input rejected (exit 255), with every fixture file hash unchanged. Invalid input precedes the already-customized refusal. The base pre_gen incorrectly accepts the renamed-package fixture (exit 0), proving the new refusal distinguishes base. Direct no-op helper probes on a scratch copy of accepted post_gen print neither `Renamed` nor `Updated`; the same probes on base print both false success lines. Thus the changed logging behavior independently distinguishes base as well. All raw stdout/stderr, exit values, and no-write hash results are preserved in `1266-independent-tests.log`.

Owner's added `test/tooling/setup_brick_log_test.dart` reviewed: it compiles the real post hook plus a same-library main, invokes both actual private helpers with unchanged defaults and then new values, checks the no-op and changed log segments, and verifies saved pubspec/iOS content. It has no literal `package:flutter_starter/` string for the setup brick to rewrite in the test source, so its assertions survive the renamed-tree workflow. Its skip behavior follows brick removal. This resolves the identified durable log-coverage gap; no API changes were introduced merely to expose helpers for testing.

Verdict: no actionable introduced defect found. Review is complete for behavior and final added test; final commit binding pending owner notification. Host full-suite, actual Mason first/second invocation, and dispatched CI results belong to the owner's separate artifacts and are not claimed as reviewer-run checks.

## Follow-up from new regression test

The owner's direct same-default test exposed a distinct semantic no-op at the initial head: `\s*$` consumed a trailing newline, so requesting `flutter_starter` changed bytes and still printed `Renamed Dart package to flutter_starter`. This was not exercised by my absent-match no-op fixture (already-customized name and id). The owner preserved the failure in `1266-log-newline-failure.log` and fixed it before merge: `_renameDartPackage` returns for the existing template package name, and actual non-default replacement uses horizontal whitespace plus a captured/re-emitted CR. I inspected the actual small diff. Identity import replacements need no work, LF stays outside the match, CRLF retains its CR, and following blank lines are no longer swallowed. No new issue found in that fix. The initial verdict is superseded by the final binding below; initial-head behavior was not fully clean until this same-default case was repaired.

## Final binding and verdict

Final reviewed and pushed head: `2bf34ba93ae087423ccf225e0d4da6694ad4b442`, base `dbea2426a5866533d01a06bb7dc1c73e821b1c8a`, PR 1277. Confirmed final five-file diff (269 insertions, 15 deletions); it comprises the original four files plus `test/tooling/setup_brick_log_test.dart` and the reviewed no-op/newline fix. The pre_gen guard and guide are unchanged from the independent runtime probes.

Independently ran at this exact head, SDK-prefixed PATH: `flutter test --no-pub --reporter expanded test/tooling/setup_brick_log_test.dart`, exit 0, **1 passed**. Raw output is `1266-independent-log-test.log` and appended to `1266-independent-tests.log`. No full suite rerun by reviewer. Owner's baseline counterfactual logs establish the new log test fails with old post_gen, while original rejection tests fail with old pre_gen.

**Final review: PASS, no actionable introduced defects remain.** The initial log-coverage gap and same-default newline/log problem are resolved on the final branch. Actual Mason CLI first/second integration, exact-head host checks, and manual setup-brick CI remain separate owner-run gates; this review does not substitute for their results.


# Focused postmerge QA: issue 1266 / PR 1277

Merge commit `8d0e63cf0d6b73fd3c285cc889932a07c77eafde`; accepted head `2bf34ba93ae087423ccf225e0d4da6694ad4b442`; base `dbea2426a5866533d01a06bb7dc1c73e821b1c8a`. Independently verified both accepted/merged tree hashes equal `e2b0abefaecedfdc97a5885370efbd3a482df07e`. No tracked or outbound mutations by reviewer.

Read the actual evidence worktree issue-1266 `format.log`, `analyze.log`, `tests.log` completions: 634 files unchanged/exit0, analyzer no issues/exit0, and 4,506 tests passed with 14 skips/exit0. These are actual owner-run full-host artifacts, not a reviewer full-suite rerun. Read final root inspection and criterion mapping draft; criteria map to actual repeated-run CLI output, real no-op/changed helper tests plus old-source counterfactual, and manually dispatched first-run setup CI.

Read the actual 54-line CLI probe: initial fixture tree matches accepted/merged tree; non-default first setup completes, is committed, Git status empty; second zeta_two/org.zeta.two setup refuses in pre_gen with exit64, manual guidance, no false success messages, Git status still empty. No partial writes remain. Earlier independent premerge probes cover removed platforms, nested monorepo output, macOS/Linux partial customization, missing root and validation priority.

Read final setup-smoke job metadata (run43731844337/job132865882065): `head_sha` is accepted head, `status=completed`, `conclusion=success`. All actual setup, renamed-tree, feature-generation and strip steps succeeded. Decoded excerpt confirms renamed-tree analyzer clean/4,495 pass22 skip, generated-feature analyzer clean/4 pass, and renamed/stripped analyzer clean/3,831 pass24 skip. `1266-ci-current.json` records eleven actual jobs: eight success and three intentionally skipped unrelated manual jobs. Quality and five strips plus Docs are successful. Distinct host/renamed/stripped totals are preserved, not conflated.

Bookkeeping observation sent to owner before publication: `1266-smoke-run.json` still captured an intermediate in_progress/null snapshot despite completed-success final job metadata; evidence draft criterion3 still used future 'must complete' wording. Refreshing/finalizing these avoids contradictory final evidence. Owner refreshed both before publication. Independently re-read final run metadata: completed/success at accepted head, and criterion3 now states concrete success with actual counts. This bookkeeping observation is resolved; no implementation defect.

Independently ran maintainer `check_issue_refs.sh --range HEAD^..HEAD`: PASS. Actual merge message carries `Refs koniz-dev/flutter-starter#1266` and no auto-closing keyword. Issue snapshot remains open, `status:in-progress`, exactly one assignee `koniz-dev`, ready for owner's evidence/closure. Tracked Git status clean. Security phase does not trigger: five-file diff is brick hooks, tooling tests and guide; no runtime auth/session/security/storage/network or dependency surface changes. No screenshots or standing goldens used as proof; no device/store/deployment verification claimed.

Reviewer postmerge test execution: SDK-prefixed PATH, `flutter test --no-pub --reporter expanded test/tooling/setup_brick_rerun_test.dart test/tooling/setup_brick_log_test.dart`. Raw output: `1266-postmerge-independent.log`. Completion and verdict appended below.

Completion: focused postmerge command exited0, all **5 tests passed**, no skips/failures. Scope is exactly the two new files; no full-suite rerun. Final scoped QA verdict **PASS** for merge8d0e63cf0d6b73fd3c285cc889932a07c77eafde with accepted-tree parity. No actionable implementation defect or unresolved evidence inconsistency found. Publication and issue closure remain the owner's responsibility.

