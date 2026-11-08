Verified in PR #1162.

| Acceptance criterion | Result and artifact |
|---|---|
| Authentication docs quote the real module list and describe token refresh, session termination and sign-out; the contracts map matches live declarations | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1151/scoped-audit.log). 29 scoped tests pass, including exact source/doc module equality, feature DI and symbol directives; docs-check.log resolves 114 symbols. |
| An explicit authModuleOverrides quote regression detects the original incomplete/drifted declaration | PASS — [regression-before.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1151/regression-before.log). The new test fails against the original providers documentation; scoped-audit.log records it passing with the corrected quote. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1151/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1151/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1151/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1151/tree-parity.log) records equality.

Independent pre-merge review: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1151/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
