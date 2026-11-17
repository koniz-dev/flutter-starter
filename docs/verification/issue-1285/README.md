# Issue 1285 - the tasks list offers Home as a root page

Merged: PR 1306, squash `591ad4095c3`. Gates on `main` at `f62242a4 docs: close the documentation findings of the 2026-11-14 audit (#1307)`.

| Criterion | Artifact | Result |
|---|---|---|
| `/tasks` reached with nothing beneath it offers a way to Home | `tasks_root_home_test.log` (app router: `go('/tasks')`) | no back button; a Home button (tooltip "Back to home") lands on `/home`. Fails on the tree before the merge |
| Opened from Home it keeps its back button | same log, second test | back button present, no Home button |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

The acceptance goldens were re-run before merge and are unchanged; none is cited. No screenshot: the assertion is on widgets and the router location.
