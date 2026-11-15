Verified in PR #1274.

| Acceptance criterion | Result and artifact |
|---|---|
| Both removal recipes are replaced by load-bearing statements and supported alternatives | PASS — [root-inspection.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1264/root-inspection.md). Read against actual consumers and contracts: retain localization APIs with one coordinated locale, and retain secure storage until concrete consumers/migration have moved. No complete module deletion or scratch-copy deletion success is claimed. |
| pub outdated no longer claims to find unused dependencies | PASS — [scope.patch](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1264/scope.patch). The shell comment now says that the command lists dependencies with newer available versions. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1264/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1264/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1264/tests.log). All actual PR checks passed. The accepted source tree is identical to merged main: [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1264/tree-parity.log).

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or device/live-backend/store assurance.
