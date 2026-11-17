# Issue 1289 - the strip runs past pub's own lockfile re-pin

Merged: PR 1300, squash `711e1e6cc3b` on `main`. Host Flutter 3.47.0; the committed lock was resolved on 3.50, so `dart run` re-pins it.

| Criterion | Artifact | Result |
|---|---|---|
| A `pubspec.lock` change alone does not trip the guard; the message names pub's re-pin and what to do | `live-repro-after.log` (fresh clone of `main` at 711e1e6, `dart run tool/strip_sample_features.dart --apply --remove-tasks`) vs `live-repro-before.log` (fresh clone at 54379d6, the tree before the merge) | after: note printed, strip completes, exit 0, `tasks` removed, lock still ` M`; before: "Refusing ... M pubspec.lock", exit 2, nothing deleted |
| Other edits still refused; nested and quoted app paths | `strip_rerun_test.log` (`test/tooling/strip_rerun_test.dart -r expanded`) | all pass, incl. lock-only at root / `app/` / `my ứng app/` and lock + another edit refused naming only the other edit |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt`, on `main-head.txt` | all exit 0 |

No screenshots; no golden is cited.
