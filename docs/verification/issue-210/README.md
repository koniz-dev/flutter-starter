# Verification evidence - issue #210

docs(architecture): the tasks sample is rejected as a host for
`PaginationHelper` and `Debouncer`, but `design-decisions.md` still calls the
question open

Shipped in PR #252, squash-merged to `main` as `0cdc0f4`. Verified against that
commit.

## Artifacts

| File | What it is |
|---|---|
| `criteria.log` | The four greps and the call-site loop the issue's criteria specify, run against the merged `main`, plus the Call-site status table as it now stands and `dart run tool/check_docs.dart` |
| `format.log` | `dart format --set-exit-if-changed lib test integration_test tool examples`, exit 0 |
| `analyze.log` | `flutter analyze`, "No issues found!", exit 0 |
| `tests.log` | `flutter test --timeout=5m`, `+2812 ~8`, exit 0 |

No PNGs: documentation-only change, so `run_acceptance.sh` ran with
`--no-goldens` and copied none. No criterion rests on a golden.

## Criteria

| Criterion | Result | Evidence |
|---|---|---|
| 1. the "still open" paragraph is replaced by a closed decision rejecting the tasks sample for both, carrying the four pagination and two debouncer reasons; `grep -n "still open"` returns no hit | PASS | `criteria.log` first block: grep exit 1, no match. The replacement section, "The tasks sample is not the host for `PaginationHelper` or `Debouncer`", is at `design-decisions.md:1281-1325` with all six numbered reasons |
| 2. nothing in the section presents #147 as an open question; `grep -n "147"` returns only past-tense references | PASS | `criteria.log` second block: three hits, at `:1249` ("was filed separately"), `:1269` (the `DateFormatter` row crediting what #147 wired), `:1283` ("#147 wired `DateFormatter` and dropped the other two halves"). All past tense; none frames a question |
| 3. the clock is evaluable without release history; `grep -nE "Review by [0-9]{4}-[0-9]{2}-[0-9]{2}"` returns at least one hit, covering every "no" row | PASS | `criteria.log` third block: one hit at `:1333`, `**Review by 2027-03-31.**` The sentence names all five "no" rows explicitly - `PaginationHelper`, `Debouncer` / `Throttler`, `LazyLoader`, `ProviderDisposal`, `PerformanceUtils` with the three mixins - and the table printed in `criteria.log` has exactly those five "no" rows |
| 4. the Call-site status table matches the tree in the loop's output | PASS | `criteria.log` fourth and fifth blocks, read together: each of the five "no" rows returns **only** its declaring `lib/core/` file; the one "yes" row, `DateFormatter`, returns three paths outside `lib/core/` |
| 5. `./scripts/dev/audit_template.sh` exits 0 | PASS | `format.log`, `analyze.log`, `tests.log` - the three gates that script runs, each ending `exit: 0`. Also run directly before the PR, exit 0 |

## Reading criterion 4's output carefully

```
PaginationHelper:  lib/core/utils/pagination_helper.dart
Debouncer:         lib/core/utils/debouncer.dart
Throttler:         lib/core/utils/debouncer.dart
LazyLoader:        lib/core/utils/lazy_loader.dart
ProviderDisposal:  lib/core/utils/provider_disposal.dart
PerformanceUtils:  lib/core/performance/performance_utils.dart
DateFormatter:     lib/core/network/interceptors/cache_interceptor.dart
                   lib/core/utils/date_formatter.dart
                   lib/features/tasks/data/models/task_model.dart
                   lib/features/tasks/presentation/screens/task_detail_screen.dart
                   lib/features/tasks/presentation/screens/tasks_list_screen.dart
```

Two things worth stating rather than leaving to the reader:

- `Throttler` returns `debouncer.dart`, not a file of its own. That is still
  "only its own `lib/core/` file" - `Throttler` is declared in `debouncer.dart`,
  which is why the table's row is `Debouncer` / `Throttler` as one entry.
- `DateFormatter` picks up `lib/core/network/interceptors/cache_interceptor.dart`
  in addition to the three `lib/features/tasks/` paths. The invariant this
  section now states requires a "yes" row to return **at least one** path
  outside `lib/core/`; three of the five do, so it holds regardless of the
  in-core hit.

The invariant is now written into the document in both directions, which is the
part that outlives this issue: a "no" row that grows an outside path means the
table is stale, and a "yes" row that loses its outside path means a call site
was deleted and the row overstates the tree.

## What this change deliberately did not do

It did not delete `PaginationHelper` or `Debouncer`. The recorded decision is
"keep, adopter-only", and the review clock it sets does not fire until
2027-03-31. koniz-dev/flutter-starter#223 holds the deletion half for
`PaginationHelper` and is gated on that review returning "delete".
