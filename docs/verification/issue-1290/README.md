# Issue 1290 - golden failure images are ignored

Merged: PR 1301, squash `9b96ff1a02c`. Gates ran on `main` at `651d42c0 docs(ci): describe active and optional workflow triggers accurately (#1302)` (also contains PR 1302).

| Criterion | Artifact | Result |
|---|---|---|
| Golden failure output is ignored | `golden-fail-run.log` (one golden replaced with another to force a real comparison failure), `golden-failures-ignored.log` | run exits 1 and writes 4 PNGs to `test/acceptance/failures/`; `git status --untracked-files=all` shows only the deliberately modified golden; `git check-ignore -v` matches `.gitignore:44:/test/**/failures/` |
| Scope stays under test/ (criterion said `**/failures/`; narrowed on purpose) | `tests.log` (`test/tooling/gitignore_golden_failures_test.dart`) | test/ failure paths ignored; `lib/features/orders/domain/failures/` not ignored |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshot is cited: the failure PNGs were generated only to be ignored and are not part of this evidence.
