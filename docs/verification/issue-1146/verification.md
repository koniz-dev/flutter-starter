Verified in PR #1157.

| Acceptance criterion | Result and artifact |
|---|---|
| Both dimensions preserve the source aspect ratio during decode | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1146/scoped-audit.log). The actual widget provider decodes a 400x200 PNG into a 100x50 bitmap for a 100x100 box; assertions are in decode-assertions.txt. regression-before.log fails against the original 100x100 decoded shape. |
| Decode regression covers 400x200 into 100x100; one dimension still bounds memory | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1146/scoped-audit.log). Both-dimension and width-only decode tests pass, retaining the 2:1 shape and width bound of 100 physical pixels. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1146/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1146/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1146/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1146/tree-parity.log) records equality.

Independent pre-merge review: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1146/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
