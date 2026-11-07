Verified in PR #1158.

| Acceptance criterion | Result and artifact |
|---|---|
| Both scripts warn about a same-name old hook and explain how to preserve its commands | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1147/scoped-audit.log). Runtime warning includes executable pre-push, pre-commit and post-checkout; source parity checks require merge/chain advice and forbid the old PowerShell skip. |
| Shell regression covers pre-push shadowing and PowerShell matches the behavior | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1147/scoped-audit.log). All 10 targeted hook/shellcheck tests pass, including monorepo, linked worktree and foreign hooks-path behavior. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1147/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1147/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1147/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1147/tree-parity.log) records equality.

Independent pre-merge review: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1147/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
