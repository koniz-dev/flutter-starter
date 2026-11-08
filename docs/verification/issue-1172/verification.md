Verified in PR #1183.

| Acceptance criterion | Result and artifact |
|---|---|
| All merged delivery fixes are recorded in changelog | PASS — [changelog-proof.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/changelog-proof.log). The six fix entries existed under Unreleased before the release freeze; the frozen section retains them and documents required adopter changes. |
| Semver choice is explained | PASS — [changelog-proof.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/changelog-proof.log). v4.0.0 is a major release because existing Fastlane invocations now require API URL configuration; the issue comment explains this choice. |
| Notes are frozen and marker bumped through green PR | PASS — [ci.json](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/ci.json). Release section is 4.0.0 dated 2026-11-08; PR #1183 updates the starter marker. Docs-only Quality ran documentation tests and Strip skipped internal runtime work. Full host format/analyzer/suite ran separately. |
| Release script dry run and publication succeed | PASS — [release-proof.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/release-proof.log). Dry-run and publish logs record the exact merged commit; the remote tag resolves to that commit. |
| Release notes match frozen section and release is Latest | PASS — [release-proof.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/release-proof.log). The GitHub latest-release endpoint names v4.0.0, and its notes match the frozen changelog section exactly apart from surrounding newlines. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1172/tree-parity.log) records equality.

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
