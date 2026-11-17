# Issue 1319 - setup brick tests skip in a manually renamed project

Merged: PR 1320, squash `6b2480f5979`.

| Criterion | Artifact | Result |
|---|---|---|
| In a tree renamed with Option B as documented, `flutter test` passes; the brick tests skip there and still run in the template | `scripts-smoke-before.txt` (run 44056717068 on `ceae85cff40`: Option B job failure), `scripts-smoke-after.txt` (run 44061486571 on the fix branch), `scripts-smoke-main.txt` (run 44065125577 on `main` `8fe1730333b`); `setup_brick_tests_template.log` (template: tests run and pass) | Option B job: failure before, success after; in the template the 5 tests run and pass |
| Host gates (G2) on `main` `6b2480f5979` | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

Also verified by hand in a copy renamed with Option B steps 1-2: the two files report 5 skips with "the project is renamed; the setup brick no longer applies", and the previous log test fails there (PR 1320 body). No screenshots.
