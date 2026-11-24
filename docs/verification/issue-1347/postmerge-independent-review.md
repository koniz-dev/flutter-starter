# Postmerge independent QA: issue1347 / PR1353

Reviewed merged main `e2f8901dd24f5fedf4bfb0b5a2543588b22c2f25`. Independently verified complete tree parity with accepted `81fa4e16a5fbe2d4a4141dcb563eaf08acca7ffd`: both trees are `37eb47765e7f1c5e6997e80e27adcbad165db9a8` and the full source diff is empty.

**Outcome: no actionable defect identified.** Reinspected formatting preflight ordering/read-only mode, version-comment normalization, ignored ref fields and tag/deletion/mixed/TTY classification, preserved Git environment cleanup/app directory selection, PowerShell7+ documented alternative and whole tracked-tree export cost. Source contracts match the verified premerge tree and the live acceptance alternatives.

Fresh merged-tree execution, using the isolated SDK and native Bash3.2:

- `flutter test test/tooling/pre_push_refs_test.dart test/tooling/shellcheck_test.dart --reporter expanded`: **8 tests passed**, exit0.
- `/bin/bash scripts/test/release_scripts_test.sh`: **all release-script fixtures passed**, exit0, including format failure before Step1/no mutations and implicit trailing-comment version handling.

Actual commands, parity output, stdout/stderr and exit codes are retained in `1347-postmerge-independent-tests.log`. The broader premerge edge probes, real formatter controls and corrected exact actual-base discrimination remain applicable by identical source tree; no duplicate fullsuite or repeated mutation experiment is claimed.

Tracked root checkout remains clean and HEAD is the merged commit. No tracked source, SDK, dependency, GitHub state or external application was changed by this review. No native Windows5.1, signed store build or live backend assurance is claimed; PowerShell uses the explicitly documented7+ alternative.
