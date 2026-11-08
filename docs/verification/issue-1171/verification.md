Verified in PR #1182.

| Acceptance criterion | Result and artifact |
|---|---|
| android/.gitignore ignores /.kotlin/ | PASS — [build-proof.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1171/build-proof.log). git check-ignore attributes the Kotlin session path to the new rule. |
| Actual debug APK build leaves android/ clean | PASS — [build-proof.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1171/build-proof.log). Build succeeded with bundled JDK 25.0.3; android porcelain output is empty and the APK SHA-256 is recorded. Full build output is in debug-build.log. |
| PR Android on JDK 25 check is green | PASS — [ci.json](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1171/ci.json). The actual toolchain floor and debug-build job succeeded alongside Quality and all five Strip variants. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1171/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1171/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1171/tests.log). All PR checks passed. The acceptance run used the exact source tree merged to main; [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1171/tree-parity.log) records equality.

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or a device/backend/store claim.
