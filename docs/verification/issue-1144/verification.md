Verified in PR #1155.

| Acceptance criterion | Result and artifact |
|---|---|
| Every lane selects BASE_URL for its resolved environment, with explicit base_url taking precedence, via one shared helper | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/scoped-audit.log). Ruby-driven environment/override tests and scans of both Fastfiles pass. |
| Tests cover staging and production and no lane hard-codes a BASE_URL variable | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/scoped-audit.log). All 15 tests passed; both-variable cases select the expected URL. |
| README states the selection rule | PASS — [readme-excerpt.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/readme-excerpt.log). The merged fastlane README documents normalized environment selection and explicit-option precedence. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/tree-parity.log) records equality.

Independent pre-merge review: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1144/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
