# Issue 147 - acceptance evidence

`feat(tasks): exercise PaginationHelper, Debouncer and DateFormatter from the
tasks sample`

Verified against `main` at `578dcb7` (PR #199, squash-merged).

**Outcome: partial.** Criteria 3 and 6 PASS. Criterion 5 PASS for the part that
is factual today. Criteria 1, 2 and 4 are **not implemented** - deliberately,
not by omission. The reasoning is in
[Wire-vs-delete, per utility](#wire-vs-delete-per-utility) below and in the
closing comment on the issue; it needs a planner decision before any code is
written, so the issue goes to `status:blocked` rather than closed.

## Per-criterion result

| # | Criterion | Result | Artifact |
|---|---|---|---|
| 1 | Tasks screen pages through `PaginationHelper`; widget test asserts page 1 then page 2 | **NOT IMPLEMENTED** | `criterion-4-grep.log` shows `PaginationHelper` still has no call site. See below. |
| 2 | Debounced search field issues one query per burst | **NOT IMPLEMENTED** | `criterion-4-grep.log` shows `Debouncer` still has no call site. See below. |
| 3 | Each task row renders a date produced by `DateFormatter`, asserted with `find.text()` | **PASS** | `criterion-3-date-tests.log` (4 tests pass), `criterion-3-negative-probe.log` (the same 4 fail against the pre-change `lib/`) |
| 4 | `grep -rl PaginationHelper lib/` and `grep -rl Debouncer lib/` each return a path outside `lib/core/utils/` | **FAIL** | `criterion-4-grep.log` - both return only their own source file |
| 5 | Design-decisions section records which utilities are exercised and which are uncalled | **PASS (partial)** | `docs/architecture/design-decisions.md`, new "Call-site status" table. Records today's facts and flags the pagination/debouncer question as open. |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | **PASS** | `format.log`, `analyze.log`, `tests.log` (2708 passed, 8 skipped) |

## What criterion 3 actually proves

`criterion-3-date-tests.log` is `flutter test test/features/tasks/presentation/screens/`
on the merged tree: 50 tests pass, including the four that bind to the wiring.

`criterion-3-negative-probe.log` is the same test files run with **only the two
production screens reverted** to `578dcb7^`. Exactly those four tests fail, and
they fail for the right reason:

```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "2024-03-15 09:05:00": []>
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "2024-03-15": []>
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "2021-06-30": []>
```

The detail-screen failure is the sharper one. The old hand-rolled
`_formatDateTime` produced `2024-03-15 09:05`; `DateFormatter.formatDateTime`
produces `2024-03-15 09:05:00`. The assertion therefore binds to
`DateFormatter` specifically, not merely to "some date is on screen".

Both assertions use `find.text()`. **No golden is or could be evidence here** -
`flutter test` renders every glyph with the Ahem font as an opaque block, so a
screenshot cannot show a date at all.

### Which half of `DateFormatter`, and why

`formatDate` / `formatDateTime` - the **local wall-clock** pair - not
`formatIso8601`.

`TaskModel.fromJson` has returned `.toLocal()` since #146, so `task.createdAt`
is already a local `DateTime`; a display row wants local wall-clock digits.
`formatIso8601` would render `2024-03-15T02:05:00.000Z` - a storage and
transport format, correct for `TaskModel.toJson` (where #146 already uses it)
and wrong for a list row.

## Wire-vs-delete, per utility

### `DateFormatter` - wired (and it was already half-wired)

The issue's premise is **stale** for this one. #146 had already wired
`DateFormatter.formatIso8601` / `parseIso8601` into `TaskModel` for
persistence, so it was not an uncalled utility when #147 was picked up. What
was genuinely missing was the **display** half.

The strongest argument for wiring it was not the issue text but a duplication
found in the code: `task_detail_screen.dart` carried its own
`_formatDateTime`, a `padLeft` chain, while `DateFormatter` sat unused one
directory away. That helper is now gone. This is the case where the utility
replaces real hand-rolled code rather than having a caller invented for it.

### `PaginationHelper` - NOT wired; recommend deleting or re-homing

Four structural objections, none of them aesthetic:

1. The tasks sample persists every task in a **single local JSON blob**
   (`tasks_data`), and `TasksLocalDataSourceImpl._readTasks()` reads all of it.
   A `loadPage(page)` callback would have to read the entire list and hand back
   a slice, so "loading page 2" performs strictly more I/O than the single read
   it replaces. That is pagination-shaped ceremony over an already-materialised
   list, not pagination.
2. `TasksListScreen` partitions tasks into **Incomplete** and **Completed**
   sections. A paged window cannot fill those sections correctly: a completed
   task that sorts late would appear under "Completed" only once the user had
   scrolled far enough to load it. That is a visible correctness regression in
   the sample.
3. Every mutation - `createTask`, `updateTask`, `deleteTask`,
   `toggleTaskCompletion` - currently ends in `_loadTasks()`. Under pagination
   each would have to either reset to page 1 (discarding the user's scroll
   position and every loaded page) or re-fetch all loaded pages. Both are
   substantial new complexity in a notifier that #180 is already open against.
4. `PaginationConfig.pageSize` defaults to 20 and the only way to create a task
   in the sample is the FAB, one at a time. Page 2 would never be reached in
   real use; only a seeded 25-task widget test would ever exercise it.

A starter's sample code is read as advice. This would be bad advice.

### `Debouncer` - NOT wired; planner decision needed

Weaker than the pagination case, and genuinely close - which is why it is being
handed back rather than decided here.

- There is **no search or filter field** on the tasks screen. One would have to
  be invented for the debouncer to have somewhere to live.
- Even granted the field, the task list is a local blob already fully in
  memory. Debouncing a synchronous in-memory `where()` adds latency for no
  benefit and teaches "debounce everything" rather than "debounce expensive or
  remote work".
- The real counter-argument, stated fairly: the template's migration path is
  "swap the local datasource for your API", and under that reading a debounced
  search demonstrates the shape an adopter will need. That argument is good
  enough that it should be a planner call, not an implementer's.

`Debouncer` is also the utility an adopter is most likely to reach for, and
`docs/architecture/design-decisions.md` explicitly rejected deleting it for
that reason. Deleting it would reverse a recorded decision, and that reversal
is not an implementer's to make.

## The PNGs in this directory prove nothing about this issue

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into the
evidence directory, so this issue ships 13 screenshots of screens it never
touched.

`goldens-checksums.txt` pairs each copy with its committed golden. **Every pair
matches**, so the run changed no golden and there is no regression to explain.
The 13 files carry 8 distinct hashes (5 are byte-identical duplicates); all 8
were opened and inspected by the closing session. They show the login screen,
the home screen, a generic empty-state and error-state list, the startup
failure screen, and the light/dark typography samples - with every glyph as an
opaque Ahem block. None shows a tasks row, and none could show a date if it
did.

**No criterion in the table above rests on any PNG.**

## Files

| File | What it is |
|---|---|
| `criterion-3-date-tests.log` | `flutter test test/features/tasks/presentation/screens/` on `578dcb7` - 50 pass |
| `criterion-3-negative-probe.log` | Same tests with only the two screens reverted to `578dcb7^` - exactly the 4 criterion-3 tests fail |
| `criterion-4-grep.log` | `grep -rl <Utility> lib/` for all seven utilities |
| `format.log`, `analyze.log`, `tests.log` | `run_acceptance.sh` gates (criterion 6) |
| `goldens.log` | Golden-tagged acceptance run |
| `goldens-checksums.txt` | Copied PNGs vs committed goldens - all pairs match |
| `*.png` | Standing goldens. Not evidence for this issue. |

## Reproducing the negative probe

No `.dart` file is committed under `docs/` on purpose: `analysis_options.yaml`
does not exclude `docs/`, so a probe source file there fails the
tasks-stripping CI variants (filed as #187). To re-run the probe:

```bash
git -C <repo> show 578dcb7^:lib/features/tasks/presentation/screens/tasks_list_screen.dart \
  > lib/features/tasks/presentation/screens/tasks_list_screen.dart
git -C <repo> show 578dcb7^:lib/features/tasks/presentation/screens/task_detail_screen.dart \
  > lib/features/tasks/presentation/screens/task_detail_screen.dart
flutter test test/features/tasks/presentation/screens/ --reporter expanded
# expect: +46 -4, the four date-rendering tests failing
git checkout -- lib/features/tasks/presentation/screens/
```
