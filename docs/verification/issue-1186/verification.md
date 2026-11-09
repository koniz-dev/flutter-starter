Verified in PR #1197.

| Acceptance criterion | Result and artifact |
|---|---|
| Activated remote values survive an in-flight, failed and timed-out refresh | PASS — [criteria-tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1186/criteria-tests.log). Three new tier-1 cases check both getFlag and getAllFlags retain true/remoteConfig; all three fail before the fix. The timeout case also pins the existing no-overlapping-fetch guard. |
| Failed or timed-out initialization still falls back locally | PASS — [criteria-tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1186/criteria-tests.log). Existing initialization timeout/failure, no-late-activation, retry and real builder/debug-screen tests remain green. All226 feature-flag tests pass (one configured skip). |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1186/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1186/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1186/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1186/tree-parity.log) records equality.

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
