Verified in PR #1198.

| Acceptance criterion | Result and artifact |
|---|---|
| API trace names and attributes omit URL passwords and query-token values | PASS — [independent-review.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1187/independent-review.log). Recording backend assertions check all emitted values for synthetic password/token leaks, including absolute credentials, relative query and a custom http_path override. The original source fails all three cases. |
| Plain /users/1 path retains its recorded behavior | PASS — [independent-review.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1187/independent-review.log). The http_path remains /users/1 while the existing trace cardinality guard produces api_get_/users/:id. Operation execution and result, safe query values and custom component attributes remain intact. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1187/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1187/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1187/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1187/tree-parity.log) records equality.

Independent pre-merge and post-merge security reviews: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1187/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
