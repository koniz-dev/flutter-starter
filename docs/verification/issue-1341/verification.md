Verified in PR #1344.

| Acceptance criterion | Result and artifact |
|---|---|
| Release TLS documentation states both transports use default/pinned contexts, explains CA/client certificate setup and removes the false ApiClient override promise | PASS — [source-inspection.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1341/source-inspection.md). Documentation alternative implemented. Source trace verifies direct TLS release behavior; the guide names HttpOverrides context/callback limitations, default-context CA and client chain/key setup before requests, and separate pinned-context customization. No runtime TLS policy changed. |
| Regression and delivery gates pass | PASS — [self-qa.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1341/self-qa.md). 4722 host tests/14 intentional skips pass with clean format/analyzer. All7 final-head CI checks pass; docs-only Quality797/2, Strip runtime skipped by scope. Fresh postmerge audit37 transport/documentation cases passes; whole-tree parity and final root self-QA inspected. No independent reviewer claimed for this docs-only diff. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1341/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1341/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1341/tests.log). All actual PR checks passed. The accepted source tree is identical to merged main: [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1341/tree-parity.log).

Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or device/live-backend/store assurance.
