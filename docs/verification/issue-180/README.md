# Acceptance evidence - koniz-dev/flutter-starter#180

Issue: **#180** - "the slice teaches two opposite answers about where a business
rule lives, and `ITasksController` has drifted with no implementor"
(`type:task`, `epic:feature-tasks`, `priority:P3`).

Shipped in **PR #214**, squash-merged to `main` as **`5c7603e`**. Every command
in this directory was run against that commit, on `main`, after the merge.

PR #214 was opened before koniz-dev/flutter-starter#177, #182 and #118 landed
and went `CONFLICTING`. It was rebased onto `main` @ `0e397bf` before merge; the
two conflicts and their resolutions are recorded in the PR body and summarised
under "Rebase" below.

## Verdict

| Criterion | Result | Evidence |
|---|---|---|
| 1. `ITasksController` resolved one way or the other, and the tree shows which - here, **deleted** along with `TasksStateSnapshot` | PASS | `criterion-1-2-contract-deleted.log` - `grep -rn "ITasksController\|TasksStateSnapshot" lib/ test/` exits 1, and the full text of `state_boundary_contracts.dart` is printed showing only `ControllerStateSnapshot`, `AuthStateSnapshot`, `IAuthController` and `ISessionTerminationSink` |
| 2. `grep -rn "tasksControllerProvider" .` returns no hit outside `.git/`; the two docs match the branch of criterion 1 that happened | PASS | `criterion-1-2-contract-deleted.log` - that grep exits 1, no swap-map **row** names `ITasksController`, and the surviving mentions in `contracts-map.md`, `adr/0005-state-boundary.md` and `boundary-migration-plan.md` are all historical notes recording the deletion |
| 3. The completion-toggle rule is expressed in exactly one layer; `tasks_repository_impl.dart` no longer hand-copies `TaskModel` fields; a unit test calls that layer directly and asserts both the flipped flag and a strictly later `updatedAt` | PASS | `criteria-3-4-5-6-static.log` (the rule is `Task.toggleCompletion` in `domain/`; the data layer is now `TaskModel.fromEntity(current[index].toggleCompletion())`, with the six-field hand copy it replaced printed from the parent commit) and `criteria-3-4-5-focused-tests.log` (`Task toggleCompletion flips isCompleted and advances updatedAt past the input`, plus the `touch` group, all green) |
| 4. `grep -n "DateTime.now()" task_detail_screen.dart` returns nothing; a widget test edits a title through the detail screen and asserts the persisted `updatedAt` advanced | PASS | `criteria-3-4-5-6-static.log` (that grep exits 1; the same grep on the parent commit hits line 103, which is the defect) and `criteria-3-4-5-focused-tests.log` (`persists an advanced updatedAt without the screen minting one`). **`criterion-4-counterfactual.log`** proves the test is load-bearing: with `Task.touch` removed from `UpdateTaskUseCase` it fails with `updatedAt must advance: 2024-01-02 00:00:00.000 vs 2024-01-02 00:00:00.000`, and goes green again on restore |
| 5. `task_detail_screen.dart` loads its task through `TasksNotifier` rather than `getTaskByIdUseCaseProvider` | PASS | `criteria-3-4-5-6-static.log` - neither `getTaskByIdUseCaseProvider` nor `core/di/providers.dart` appears in the screen; it calls `ref.read(tasksNotifierProvider.notifier).taskById(...)`, and `getTaskByIdUseCaseProvider` is now read only by the notifier. `criteria-3-4-5-focused-tests.log` runs the three `taskById` tests, including `leaves the shared list snapshot alone` |
| 6. `deleteCompletedTasks` is either removed everywhere or gains a use case plus a production caller - here, **removed** | PASS | `criteria-3-4-5-6-static.log` - `grep -rn "deleteCompletedTasks" lib/ test/ tool/ integration_test/` exits 1, against 13 occurrences on the parent commit (contract, implementation, 11 lines of tests) |
| 7. `flutter test test/features/tasks/` exits 0 with no behavioural assertion weakened; changed assertions listed in the PR body | PASS | `criterion-7-tasks-suite.log` - 319 tests, `All tests passed!`, `exit=0`. The six removed test names are all `deleteCompletedTasks` cases; the nine added ones are named; the koniz-dev/flutter-starter#61 atomicity assertions (`mutateTasks(any())).called(1)`, `verifyNever(getTaskById)`, `verifyNever(saveTask)`) are shown still present |
| 8. `./scripts/dev/audit_template.sh` exits 0 | PASS | `criterion-8-audit_template.log` - env asset guard, format (365 files, 0 changed), `flutter analyze` (`No issues found!`), `flutter test` (`+2794`, all passed), `exit=0` |

No criterion was routed to `status:needs-uat`: all eight are greps, unit tests,
widget tests and script exit codes, every one of which this harness drives.

## Files

| File | What it is |
|---|---|
| `criterion-1-2-contract-deleted.log` | Criteria 1 and 2, plus regression greps for koniz-dev/flutter-starter#182 and #177 |
| `criteria-3-4-5-6-static.log` | Criteria 3-6, source and greps, each contrasted with the parent commit `0e397bf` |
| `criteria-3-4-5-focused-tests.log` | The named tests behind criteria 3, 4 and 5, run individually |
| `criterion-4-counterfactual.log` | Breaks `UpdateTaskUseCase`, shows the criterion-4 test fail, restores, shows it pass |
| `criterion-7-tasks-suite.log` | Criterion 7: the whole `test/features/tasks/` suite, and the added/removed test inventory |
| `criterion-8-audit_template.log` | Criterion 8: `./scripts/dev/audit_template.sh` |
| `standing-guards.log` | `tool/check_docs.dart`, `tool/check_epic_coverage.dart`, the #118/#175 guard tests, the #146 `TaskModel` timestamp tests, `check_issue_refs.sh`, and proof no `flutter pub get` churn was committed |
| `format.log`, `analyze.log`, `tests.log` | Produced by `./scripts/test/run_acceptance.sh 180 --no-goldens` |

The greps in `criterion-1-2-contract-deleted.log` and
`criteria-3-4-5-6-static.log` were run **outside** the working tree and the
output copied in, so no grep could match its own log file. That matters for
criterion 2, whose whole claim is that a string occurs nowhere.

## Goldens

The runner was invoked with `--no-goldens`. Nothing in #180 is visual - every
criterion is a grep, a test name or an exit code - so this directory contains
**no PNG**, and no criterion rests on a golden. The standing goldens under
`test/acceptance/goldens/` were therefore neither run nor copied in, and are
unmodified on `main`.

`tests.log` reports `8 skipped tests`: those are the `golden`-tagged acceptance
tests that [`dart_test.yaml`](../../../dart_test.yaml) skips by default.

## Rebase

Two conflicts, both resolved by keeping **both** intents rather than reverting
`main`:

- `lib/features/tasks/presentation/screens/task_detail_screen.dart`, the import
  block. `main` (koniz-dev/flutter-starter#177) had added
  `core/routing/navigation_extensions.dart` and dropped `go_router`; this change
  drops `core/di/providers.dart`. Both survive: the screen imports
  `navigation_extensions.dart`, calls `context.popRoute<void>()` at `:119` and
  `:161`, and loads through `TasksNotifier.taskById`.
- `docs/architecture/contracts-map.md`, the "Read the Status column" paragraph.
  `main` had rewritten it for #177's deletion of `AppNavigator`; this change had
  rewritten it for the deletion of `ITasksController`. The merged text names two
  remaining not-load-bearing rows (`AppDesignTokens`, `IAuthController`) and
  records both deletions. koniz-dev/flutter-starter#182's Status column, legend
  and `IHttpResponseCache` / `ISessionTerminationSink` rows are intact, and
  neither phantom identifier #182 removed was reintroduced - see the greps in
  `criterion-1-2-contract-deleted.log`.

`adr/0005-state-boundary.md` and `migrations/boundary-migration-plan.md`
auto-merged; ADR 0005 is still **Proposed** and still carries its
"Implementation status" section.

No hunk was dropped. All four defects #180 describes were still present on
`main` @ `0e397bf`, as the parent-commit contrasts in
`criteria-3-4-5-6-static.log` show.

Three line-number citations in `contracts-map.md` were refreshed so its
"checked against `lib/` at `<sha>`" header is true at `0e397bf`:
`task_detail_screen.dart:114`/`:156` became `:118`/`:160` (moved by this change)
and `cache_interceptor.dart:60` became `:97` (moved by
koniz-dev/flutter-starter#188 on `main`).

## QA

**Self-QA**, not a separate `qa` pass - this was a solo implementer session with
no orchestrator to dispatch one. Per
[`.claude/agents/implementer.md`](../../../.claude/agents/implementer.md) that
is the weaker of the two, and the reader should weigh it accordingly. The
checklist was run after the evidence existed and before the closing comment:
every row above names a file in this directory; every one of those files was
re-opened and read; no row rests on a golden, because there are none; the merged
commit carries `Refs koniz-dev/flutter-starter#180` and no auto-closing keyword
(`standing-guards.log`); and nothing was routed to `needs-uat`.
