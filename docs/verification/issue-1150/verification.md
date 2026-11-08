Verified in PR #1161.

| Acceptance criterion | Result and artifact |
|---|---|
| One canonical guide covers the session seam, sign-out binding or action removal, and shared test helpers; the other links to it without obsolete router edits | PASS — [guide-excerpt.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1150/guide-excerpt.log). The complete procedure and onboarding link are captured. Independent review verified the referenced source and consumer scan; docs-check.log and scoped-audit.log validate links and source/DI instructions. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1150/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1150/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1150/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1150/tree-parity.log) records equality.

Independent pre-merge review: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1150/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
