# Independent postmerge QA and risk-gated security: issue 1262

Reviewed merged main `6699ce7f381bce67da5945b071e4c047fd68ee54` on 2026-11-15, PR1272; base `e2e848b51354c0beee82c4f3d984d25d9ca539fb`, accepted head `90866bb32421dc43bdf07ea0ae8eb9493ddb6d4a`. Independently compared tree IDs: accepted and merged are both `70ba4fb3a3b2887ef00f8857f654507aef940dd2`. Working tree was clean.

## Result

No new QA or security finding. Substantive behavior passes independent postmerge focused checks. Evidence publication and closure remain the root session's G4 work; this review does not certify unpublished evidence as committed or pushed.

## Independently rerun

Command: `/Users/nguyenanhkiet/Playground/flutter-starter/.git/codex-issue-work/sdk-350/flutter/bin/flutter test --no-pub test/features/auth/manual_logout_session_test.dart .git/codex-issue-work/1262-race-probe_test.dart --reporter expanded`.

Exit 0, `00:03 +6: All tests passed!`. Raw focused log: `.git/codex-issue-work/1262-postmerge-focused.log`.

Two committed regressions plus the four-case private probe reran on merged main. The private file includes the two regression scenarios and additional actual-graph queued sign-in cases for late logout success and failure. Both local tokens and cached user disappear while remote logout remains held, auth user becomes null, router enters LoginScreen and Home disappears. The later server failure is reported as state/error with localized text. Pending logout keeps LoginSubmit disabled. Programmatic login B waits for teardown, then survives old logout success/failure with user B and access-B, stopped loading, no stale failure and Home restored. No old-user reinstatement observed.

## Raw evidence and process inspected

- Read live issue through read-only REST bridge: issue OPEN, assigned only to `koniz-dev`, exactly one status (`status:in-progress`), type:bug, epic:feature-auth, priority:P2. Actual two acceptance criteria match the focused cases above.
- Ran maintainer `check_issue_refs.sh --range e2e848b51354c0beee82c4f3d984d25d9ca539fb..6699ce7f381bce67da5945b071e4c047fd68ee54`: exit 0, merged message carries `Refs koniz-dev/flutter-starter#1262` and no auto-closing keyword.
- Read `$E/docs/verification/issue-1262/format.log`: 630 files, zero changed, exit 0; `analyze.log`: no issues, exit 0; `tests.log`: 4489 passed, 14 skipped, exit 0. These are inspected root-run results, not a duplicate full-suite run by this reviewer.
- Read private `1262-counterfactual.log`: both new cases fail against the original source with retained old user. Inspected negative-control evidence; did not alter source or rerun the negative control.
- Read private `1262-goldens.log`: five existing logout/forced-logout/restore acceptance tests pass. No duplicate golden run and no screenshot/text-content claims made by this reviewer. At inspection, E held only format/analyze/tests logs; root is still collecting/publishing other logs and standing PNG checksums. No criterion depends on interpreting Ahem screenshots.
- Read captured `1262-ci-current.json`: Quality gate and all five Strip checks SUCCESS. No duplicate CI request.

## Security scope

Auth change qualifies for risk-gated security review. Rechecked immediate session removal, actual generation/teardown protections, late success/failure behavior and queued next-session preservation. Remote revocation uses captured old tokens; cleanup and failure precedence are unchanged. No new credential persistence, logging, remote destination, dependency or secret exposure is added by the five-file diff. Test/log token strings are fixture values (`access-A`, `refresh-A`, `access-B`), not real credentials. Security conclusions are limited to host-verifiable behavior; no backend/device verification claimed.

No tracked files or Git state modified, and no outbound comments/issues/other mutations performed. Root retains evidence publication and issue closure.
