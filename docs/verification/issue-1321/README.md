# Issue 1321 - FileLogOutput opens its file once

Merged: PR 1322, squash `3359e6d2f17`. Gates on `main` at `3359e6d2 fix(logging): open the log file once when init runs twice (#1322)`.

| Criterion | Artifact | Result |
|---|---|---|
| A second or concurrent init opens no second sink; no line lost; no sink left open | `init_once_test.log` (`file_log_output_init_once_test.dart`) | 4 pass; "a second init ..." and "Logger's own init call ..." fail before the fix |
| Root cause shown | PR 1322 body: probe on the unfixed code wrote `A1\|A2\|B1\|B2` (A3 lost) and the first sink never closed | reproduced deterministically |
| `uncaught_error_handlers_test` passes under load | PR 1322 body: 25/25 runs while `test/tooling` and `test/core` ran in parallel | pass (it had failed twice under such load before the fix) |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0; 4688 passed |

No screenshots.
