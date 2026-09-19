# Issue 61 - concurrent task mutations lose writes; setState after dispose

Verification evidence for koniz-dev/flutter-starter#61, against the merged fix
on `main` (PR #95, commit `387d59c`).

## Provenance

The fix merged with CI green, but the session that wrote it was terminated by
an API rate limit before it ran acceptance verification. This evidence was
produced afterwards by the orchestrating session, in a clean detached worktree
at `origin/main` - not in the implementer's tree.

## Criterion to artifact

All 11 PASS. Test names below appear verbatim in
`tasks-concurrency-tests.log` (440 tests, exit 0).

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | Concurrent mutations do not lose writes; interleaved delete-A / toggle-B in read-read-write-write order, both survive | PASS | `test/features/tasks/data/tasks_mutation_concurrency_test.dart` - *deleted task A must not be resurrected by the toggle*, *the toggle of B must not be lost to the delete*, *the two mutations never read concurrently* |
| 2 | Double-tap yields an odd number of toggles, or the control is disabled in flight | PASS | `tasks_provider_test.dart:914` - *a second toggle while one is in flight is ignored* |
| 3 | Pop before load resolves produces no exception; same guard on the three `ref.invalidate` sites in `feature_flags_debug_screen.dart` | PASS | `tasks_provider_test.dart:965,983` - *disposing the provider mid-mutation throws nothing*, *disposing the provider mid-create throws nothing*; plus *FeatureFlagsDebugScreen unmounting mid-override does not touch ref after dispose* |
| 4 | Clearing the description persists an empty/absent description | PASS | `task_detail_screen_test.dart:694` - *should clear the description when it is emptied*, paired with `:744` *should keep a description that was not cleared* |
| 5 | 100 tasks in a tight loop yield 100 distinct ids | PASS | *CreateTaskUseCase should create 100 tasks with unique ids and no delay* |
| 6 | A failed mutation shows the error without removing the loaded list | PASS | `tasks_provider_test.dart:943` - *a failed mutation keeps the already-loaded tasks* |
| 7 | `await createTask(...)` completes only once `state.tasks` reflects it; overlapping reloads cannot apply an older snapshot last | PASS | `tasks_provider_test.dart:864` - *createTask resolves only once state.tasks reflects it*; `:887` - *a slow earlier reload cannot land after a newer one* |
| 8 | Post-`await` `state =` writes in the four mutation methods carry `ref.mounted` | PASS | `lib/features/tasks/presentation/providers/tasks_provider.dart` - 6 `ref.mounted` guards |
| 9 | `Task` equality accounts for `updatedAt` | PASS | `lib/features/tasks/domain/entities/task.dart:72` - `updatedAt == other.updatedAt` inside `operator ==` |
| 10 | Pull-to-refresh works in the empty and error states | PASS | `tasks_list_screen_test.dart:838` - *pull-to-refresh works in the empty state*; `:857` - *pull-to-refresh works in the error state* |
| 11 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit_template.log` - `AUDIT_EXIT=0`, `+2407 ~5: All tests passed!` |

## On the PNGs in this directory

`run_acceptance.sh` copies the repository's standing acceptance goldens into
every evidence directory automatically. All six here were confirmed
**byte-identical** (SHA-256) to their committed masters under
`test/acceptance/goldens/`, so they are render-regression checks only: this
change broke no existing screen.

**No criterion above rests on them.** Criteria 1-11 are about mutation
ordering, lifecycle guards, id uniqueness, equality and refresh behaviour -
none of which a screenshot can establish, and `flutter test` renders text with
Ahem so a golden cannot show wording in any case.

## Note on criterion 2

The criterion allowed either of two outcomes: an odd number of toggles, or the
control disabled while in flight. The implementation took the second route -
the second toggle is ignored rather than queued - which is why the test is
named *a second toggle while one is in flight is ignored* rather than counting
flips.
