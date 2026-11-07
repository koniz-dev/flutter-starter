Verified in PR #1160.

| Acceptance criterion | Result and artifact |
|---|---|
| Dirty Git trees or modified overwrite targets refuse before deletion unless force is explicit | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1149/scoped-audit.log). Tests cover staged/unstaged/untracked/unrelated edits, both hidden-index flags, both mutation paths, missing Git, clean CRLF and nested monorepo attributes; contents, feature directories and tool remain intact on refusal. |
| Refusal and force paths are tested and the adopter guide explains the guard | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1149/scoped-audit.log). 30 scoped tests pass, including forced dirty/missing-Git success. regression-before.log fails against the original tool. guide-excerpt.log records the warning about golden replacements, committed edits, recovery and force. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1149/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1149/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1149/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1149/tree-parity.log) records equality.

Independent pre-merge review: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1149/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.

The additional setup-brick workflow completed successfully on the accepted head (manual-result.json). Its CLI watcher timed out reading the final status, so the completed GitHub run result was independently fetched and checked. renamed-targets.log records the two rename regressions passing; poststrip-probe.log records three passing cases after a committed bricks-only strip.
