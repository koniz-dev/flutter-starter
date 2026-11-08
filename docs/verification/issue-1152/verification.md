Verified in PR #1163.

| Acceptance criterion | Result and artifact |
|---|---|
| Replace the incomplete Adding Custom Features tutorial with a link to adding-features.md | PASS — [guide-section.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1152/guide-section.log). The complete replacement section links to the canonical guide and names data/DI, localization, route/home and test steps. docs-check.log verifies all links and symbols; focused-tests.log records four passing documentation tests. CI ran docs-reader tests; Strip jobs intentionally skipped their strip/analyze/test steps for this Markdown-only change. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1152/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1152/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1152/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1152/tree-parity.log) records equality.

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
