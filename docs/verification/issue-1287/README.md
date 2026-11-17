# Issue 1287 - unused checkExamples key removed

Merged: PR 1303, squash `f47a3a0d37d`. Gates on `main` at `2526cefb fix(release): select exported IPA artifacts without assuming Runner.ipa (#1305)`.

| Criterion | Artifact | Result |
|---|---|---|
| Key removed from the four ARB files and regenerated | `check-examples-removed.log` | `git grep checkExamples` finds nothing; `flutter gen-l10n` leaves `lib/l10n` unchanged, so the generated files match the ARBs |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited.
