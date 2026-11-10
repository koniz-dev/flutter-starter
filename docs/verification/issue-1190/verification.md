Verified in PR #1201.

| Acceptance criterion | Result and artifact |
|---|---|
| Documentation uses token contracts and repository sign-out, without token-value prints | PASS — [independent-review.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1190/independent-review.log). Current docs have no guard violations; original docs produce 21. API/SessionManager verification confirms ITokenStore reads and coordinated AuthRepository/logout action ownership, including logout attempts after read errors. |
| Regression test rejects unsafe session-key access and token logging | PASS — [local-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1190/local-audit.log). 49 guard cases plus CI markdown-scope coverage pass. Cases include null-aware/postfix/cascade/typed aliases, comments/nested comments, safe literal text, interpolation, and fenced/inline/Dart-doc/blockquote examples. The test is automatically included in the existing test/docs CI scope. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1190/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1190/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1190/tests.log). All actual PR checks passed. The accepted source tree is identical to merged main: [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1190/tree-parity.log).

Independent reviews: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1190/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or device/live-backend/store assurance.
