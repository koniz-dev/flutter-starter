# Issue 1291 - workflow trigger text describes what exists

Merged: PR 1302, squash `651d42c0a64`. Gates ran on `main` at `651d42c0 docs(ci): describe active and optional workflow triggers accurately (#1302)`.

| Criterion | Artifact | Result |
|---|---|---|
| The prompt and report describe what exists | `setup_ci-runs.log` (real workflows: bare `--yes`; `n` at the prompt) | `--yes`: deploy-* listed as manual-only, then "no workflow other than deploy-* had a commented trigger ... pass --deploy-trigger"; prompt names the commented triggers and deploy-*, declining says "No workflow was changed"; no file changed in either run |
| The coverage.yml header describes what exists | `tests.log` (`test/tooling/setup_ci_test.dart`), header in the merged file | header: manual + weekly, no commented triggers, how to add `pull_request:`; `test-coverage.md` agrees |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited.
