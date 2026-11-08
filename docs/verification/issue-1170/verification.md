Verified in PR #1181.

| Acceptance criterion | Result and artifact |
|---|---|
| IKeyValueStore documents false mutation failures and caller obligations | PASS — [contract-scope.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1170/contract-scope.log). The doc names false results, reporting success, migration source deletion and session cleanup. Non-documentation source remains identical. |
| Analyzer passes; Docs check applies only if Markdown changed | PASS — [criterion-analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1170/criterion-analyze.log). Flutter analyze exits 0. The only changed path is a Dart doc comment; no Markdown changed, so the conditional Docs workflow is not required. Full PR checks and host acceptance are also verified. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1170/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1170/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1170/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1170/tree-parity.log) records equality.

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
