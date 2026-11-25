Verified in PR #1398.

| Acceptance criterion | Result and artifact |
|---|---|
| Every UI/navigation sign-in example uses the session owner or is explicitly non-UI. | PASS — [source-inspection.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1372/source-inspection.md). UI snippets use AuthNotifier; direct use-case examples are labelled domain/service. The real graph verifies token persistence and signed-in session, and the provider widget compiles. See source.patch, baseline.log and postmerge-audit.log. |
| A test/docs check rejects a loginUseCase example paired with navigation. | PASS — [guard.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1372/guard.log). Tracked Markdown plus nested Dartdoc guard and positive/negative fixtures pass. baseline.log demonstrates rejection of the original examples and the original signed-out session defect. |

Format, analyzer and full suite passed: [format.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1372/format.log), [analyze.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1372/analyze.log), [tests.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1372/tests.log). All actual PR checks passed. The accepted source tree is identical to merged main: [tree-parity.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1372/tree-parity.log).

Independent reviews: [review.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1372/review.md). Self-QA inspected the named artifacts, source assertions, refs and status labels before closing. No screenshots were collected (`--no-goldens`); no criterion rests on standing goldens or device/live-backend/store assurance.
