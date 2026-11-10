Verified in PR #1202.

| Acceptance criterion | Result and artifact |
|---|---|
| Every tracked hook and shell entrypoint has LF Git attributes | PASS — [local-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1191/local-audit.log). Tier-1 test enumerates Git-tracked hooks, .sh files and shell shebangs; queries git check-attr eol for each. It fails on the baseline with unspecified attributes. |
| An autocrlf=true clone runs commit-msg successfully | PASS — [clone-after.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1191/clone-after.log). Actual local clone, core.autocrlf=true, checks out accepted commit; hook has zero CRLF lines and accepts a valid Conventional Commit with exit 0. Baseline clone has 56 CRLF lines and fails with exit 1. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1191/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1191/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1191/tests.log). All actual PR checks passed. The accepted source tree is identical to merged main: [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1191/tree-parity.log).

Independent reviews: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1191/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or device/live-backend/store assurance.
