# Issue 187 - the strip script now accounts for Dart files under docs/

`tool/strip_sample_features.dart` deleted `lib/features/tasks` and
`lib/features/feature_flags` but never looked under `docs/`, and its
`_collectStrippedViolations` guard scanned only `lib`, `test`,
`integration_test` and `examples`. `analysis_options.yaml` does not exclude
`docs/`, so an evidence probe importing a sample feature let the strip exit 0
and then failed `flutter analyze` two steps later in `strip-smoke.yml` - which
is what happened to both tasks-removing variants on PR #171.

## What changed

Two things, both in `tool/strip_sample_features.dart`:

1. `_deleteDocsProbes` deletes any `docs/verification/**/*.dart` that names a
   stripped module, printing each deletion. The script already deleted
   `docs/features/tasks.md` on the same reasoning.
2. `docs` joined the roots in `_collectStrippedViolations`. That covers the
   rest of `docs/`, which is deliberately **not** deleted: a Dart file outside
   `docs/verification/` was written by a human to be read, so the strip fails
   loudly (exit 3, naming the file) rather than quietly removing it.

## Evidence

| File | What it is |
|---|---|
| `criteria-1-4-strip-probe.log` | Every acceptance case, driven against the real working tree and restored with `git checkout -- .` + `git clean -fd` between each. Runs `before` on `origin/main`'s copy of the script, then all four probe cases, the backstop case, and all three variants on a clean tree |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 187 --no-goldens` |

`--no-goldens`: this change is a command-line tool, nothing renders, no PNG is
in this directory, and no criterion rests on a golden. The standing goldens
under `test/acceptance/goldens/` were neither copied here nor touched.

The `flutter test` compact-reporter progress lines were elided from
`criteria-1-4-strip-probe.log` (they are single carriage-return-driven lines of
40-130 KB each); the final `+N ~8: All other tests passed!` status line and the
exit code are kept verbatim. Nothing else was edited out.

## Before - the reported defect, reproduced

`criteria-1-4-strip-probe.log`, section `BEFORE`. With
`docs/verification/issue-000/probe.dart` importing
`package:flutter_starter/features/tasks/domain/entities/task.dart` and
`origin/main`'s script:

```
$ dart run tool/strip_sample_features.dart --apply --remove-tasks   # pre-fix script
Strip complete. Run: flutter pub get && flutter analyze && flutter test
strip exit: 0
$ flutter analyze   # pre-fix
  error • Target of URI doesn't exist: ... • docs/verification/issue-000/probe.dart:2:8 • uri_does_not_exist
analyze exit: 1
```

Exactly the state criterion 1 forbids: script 0, analyze 1.

## Criterion 1 - tasks probe + `--remove-tasks`

PASS via the second disjunct ("leaves a tree where `flutter analyze` exits 0").
`criteria-1-4-strip-probe.log`, case `criterion 1`:

```
Deleted docs/verification/issue-000/probe.dart: an evidence probe importing a
stripped module (package:flutter_starter/features/tasks/). docs/ is analyzed,
so leaving it would break flutter analyze.
strip exit: 0
probe still on disk? NO (deleted by the strip)
No issues found! (ran in 2.7s)
analyze exit: 0
```

## Criterion 2 - tasks probe + `--apply` (both samples)

PASS. Same log, case `criterion 2`: the same deletion line, `strip exit: 0`,
`No issues found!`, `analyze exit: 0`.

**Reading of "with that file present".** Taken as "present in the tree the
strip was run against", which is the only reading any fix can satisfy: once
`lib/features/tasks` is gone, an import of it cannot resolve, so no
implementation can leave the probe on disk *and* have `flutter analyze` exit 0.
The strip therefore deletes it and says so on stdout. The alternative root cause
the issue offers - fail loudly, exit non-zero - satisfies criterion 1 but leaves
criterion 2's `flutter analyze` at exit 1, so it cannot satisfy the pair.

## Criterion 3 - the same two cases with feature_flags

PASS. Cases `criterion 3a` (`--remove-feature-flags`) and `criterion 3b`
(`--apply`), with the probe importing
`package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart`.
Both: deletion line naming
`package:flutter_starter/features/feature_flags/`, `strip exit: 0`,
`No issues found!`, `analyze exit: 0`.

## Backstop - docs/ outside docs/verification/ still fails loudly

Not a numbered criterion; it is the second half of the change and is proved in
the case labelled `backstop`. `docs/guides/probe_187.dart` importing the tasks
entity, with `--remove-tasks`:

```
Strip finished but forbidden references remain in code the analyzer reads:
.../docs/guides/probe_187.dart: references stripped module (package:flutter_starter/features/tasks/)
Fix imports or excludes before committing.
strip exit: 3
probe still on disk? YES
```

The file is untouched and the run fails at the strip step, locally, instead of
at `flutter analyze` in CI.

## Criterion 4 - with no such file, all three variants behave as before

PASS. Three cases at the end of `criteria-1-4-strip-probe.log`, each mirroring
`strip-smoke.yml` (strip, `flutter pub get`, `flutter analyze`, `flutter test`):

| Variant | strip | pub get | analyze | test |
|---|---|---|---|---|
| `--apply` (both-samples-removed) | 0 | 0 | 0 `No issues found!` | 0, `+2277 ~8: All other tests passed!` |
| `--remove-tasks` | 0 | 0 | 0 `No issues found!` | 0, `+2464 ~8: All other tests passed!` |
| `--remove-feature-flags` | 0 | 0 | 0 `No issues found!` | 0, `+2607 ~8: All other tests passed!` |

No deletion line appears in any of the three: the two Dart files that do live
under `docs/` today (`docs/verification/issue-48/aot_probe.dart` and
`docs/verification/issue-121/diagnosis_probe_test.dart`) import only
`core/` modules, which no variant strips, so neither is touched.

## Criterion 5 - audit_template.sh exits 0

`format.log` (365 files, 0 changed, `exit: 0`), `analyze.log`
(`No issues found!`, `exit: 0`), `tests.log`
(`+2794 ~8: All other tests passed!`, `exit: 0`) - the three gates
`./scripts/dev/audit_template.sh` runs, driven by
`./scripts/test/run_acceptance.sh 187 --no-goldens`, which reported
`RESULT: all gates passed.`
