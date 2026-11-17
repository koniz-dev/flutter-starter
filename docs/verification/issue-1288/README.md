# Issue 1288 - format_dart.sh anchors to the project root

Merged: PR 1299, squash `54379d60735` on `main`.

| Criterion | Artifact | Result |
|---|---|---|
| Anchors to the root; `--check` from a subdirectory fails on a misformatted tree | `subdir-check-after.log` (merged script, run from `lib/` with `tool/zz_probe.dart` misformatted) vs `subdir-check-before.log` (previous script, same tree) | after: checks 640 files, exit 1; before: "No file or directory found" x5, exit 0 |
| Regression test | `format_check_test.log` (`scripts/test/format_check_test.sh`, run under `flutter test` by `test/tooling/format_check_readonly_test.dart`) | `--check from lib/: exit 1`, OK |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt`, on `main-head.txt` | all exit 0; 4625 tests passed, 14 skipped |

No screenshots: the change is a shell script; no golden is cited.
