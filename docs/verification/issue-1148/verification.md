Verified in PR #1159.

| Acceptance criterion | Result and artifact |
|---|---|
| Template uses pinned transport, release HTTPS refusal and in-memory cache; docs explain refresh limits | PASS — [enabled-probe.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1148/enabled-probe.log). Enabled code analyzes with real GraphQL/HTTP dependencies. enabled-template.txt records actual code; scoped-audit.log guards transport/cache/policy and documentation. |
| A check fails if SslPinning disappears or HiveStore returns | PASS — [scoped-audit.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1148/scoped-audit.log). New opt-in template guard passes; regression-before.log demonstrates failure against the original source. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1148/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1148/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1148/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1148/tree-parity.log) records equality.

Independent pre-merge review: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1148/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
