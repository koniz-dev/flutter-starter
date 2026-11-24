Verified in PR #1356.

| Acceptance criterion | Result and artifact |
|---|---|
| Rename guide drops the stale file count | PASS — [source-inspection.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1348/source-inspection.md). The count is removed; import re-sort/pub-get/analyze instructions remain. No replacement benchmark is invented. |
| Configuration troubleshooting removes the asset-loader step | PASS — [source-inspection.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1348/source-inspection.md). Removed the existing-loader-call check and retained build define/key/rebuild instructions, consistent with inspected startup and EnvConfig fallback behavior. |
| Required documentation/regression/host/CI and QA gates pass | PASS — [self-qa.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1348/self-qa.md). Host4733/14 passes with clean format/analyzer; all7 checks green, docs-only Quality806/2 and intentional Strip runtime skip. Fresh merged22-test G2 audit, whole-tree parity and root self-QA inspected; no independent review claimed for docs-only changes. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1348/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1348/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1348/tests.log). All actual PR checks passed. The accepted source tree is identical to merged main: [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1348/tree-parity.log).

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or device/live-backend/store assurance.
