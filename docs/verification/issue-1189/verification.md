Verified in PR #1200.

| Acceptance criterion | Result and artifact |
|---|---|
| Login validates the trimmed email and reaches its use case with that address | PASS — [criteria-tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1189/criteria-tests.log). The real login screen accepts an address with a trailing space; the use case receives a@example.com and the exact original password, including its trailing space. Baseline makes no use-case call. |
| Registration validates the trimmed email and reaches its use case with that address | PASS — [criteria-tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1189/criteria-tests.log). The real registration screen submits the trimmed address and unchanged password/name to its use case. Both widget regressions fail before the fix; all 344 auth tests also pass. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1189/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1189/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1189/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1189/tree-parity.log) records equality.

Independent pre-merge and post-merge security reviews: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1189/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
