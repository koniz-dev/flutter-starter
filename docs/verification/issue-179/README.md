# Issue 179 - put all three local data sources on `IKeyValueStore`

Merge commit under test: `48ba708c3f885c5d9faf6887e1ced0fd4bb31a20`
(PR koniz-dev/flutter-starter#195, squash-merged to `main`).

Runner: `./scripts/test/run_acceptance.sh 179 --no-goldens`, exit 0, plus the
per-criterion commands below.

## No screenshots, deliberately

`--no-goldens` was used because nothing in this change renders: the diff is four
library files that only swap a parameter type, one test helper, and two new unit
tests. There is no PNG in this directory, so **no criterion rests on a golden**
and the standing `test/acceptance/goldens/*.png` were neither copied here nor
re-rendered. `ls docs/verification/issue-179/*.png` matches nothing.

## Criterion results

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | No `*_local_datasource.dart` depends on `StorageService`; all three depend on `IKeyValueStore` (+ `ITokenStore` where secure storage is involved) | PASS, qualified - see below | `criterion-1-grep.txt` |
| 2 | The two provider files read `keyValueStoreProvider` | PASS | `criterion-2-providers.txt` |
| 3 | `TasksLocalDataSourceImpl` driven by an in-memory fake `IKeyValueStore`, no `SharedPreferences` | PASS | `criterion-3-4-seam-tests.log` |
| 4 | Same for `FeatureFlagsLocalDataSourceImpl` | PASS | `criterion-3-4-seam-tests.log` |
| 5 | `flutter test test/features/tasks/ test/features/feature_flags/` exits 0; no existing test changed an assertion | PASS | `criterion-5-scoped-tests.log`, `criterion-5-no-assertion-changes.txt` |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `criterion-6-audit.log` |

## Criterion 1, stated precisely

The criterion has two clauses. The substantive one holds outright:
`criterion-1-grep.txt` shows `tasks_local_datasource.dart:45` and
`feature_flags_local_datasource.dart:27,30` now declaring `IKeyValueStore`, and
`auth_local_datasource.dart:54,57` declaring `IKeyValueStore` + `ITokenStore`.

The clause written as a literal command does not, on its own terms. `grep -rn
"StorageService" lib/features` still returns five lines, all in
`auth_local_datasource.dart`, and all of them are the substring inside
**`SecureStorageService`** - the legacy `secureStorageService` fallback in that
constructor. That is the secure store, a different type from the concrete
key-value `StorageService` this issue is about; the issue's own table already
lists auth as depending on `IKeyValueStore` / `ITokenStore`. The word-boundary
form, `grep -rnw "StorageService" lib/features`, returns nothing.

`auth_local_datasource.dart` was deliberately left alone: the planner's scope
note limits this diff to the two data sources, their providers, and tests, and
`epic:feature-auth` had queued work. Removing that fallback is a breaking
constructor change for template consumers and is filed as
koniz-dev/flutter-starter#196.

## Nothing persisted changed

`criterion-5-no-assertion-changes.txt` shows it three ways:

- no added or removed line in either data source mentions `_tasksKey`,
  `_prefix`, `'tasks_data'`, or `feature_flag_override`
- `lib/core/storage/` is not in the merged diff at all, so the migration
  framework (#60), its startup wiring (#101), and the `exceptionName` pattern
  (#142) are untouched, version stamps included
- `TaskModel` (#146) is not in the diff

Two of the new tests assert the persisted shape directly rather than by
inspection: the tasks fake ends with exactly one key, `tasks_data`, holding a
JSON string containing `"id":"task-1"`; the feature-flags fake ends with
`feature_flag_override_new_checkout` holding the string `'false'` and
`feature_flag_override_keys` holding `['new_checkout']`.

## Why the seam is real rather than nominal

The fake is `InMemoryKeyValueStore` in `test/helpers/in_memory_stores.dart:131`,
which implements **only** `IKeyValueStore`. It is not a `StorageService` and is
not a mock, so the tests assert on what was actually persisted. If either data
source reaches for the concrete service again, these tests stop compiling rather
than silently keeping the coupling.

The pre-existing `InMemoryStorage` in the same file was left as it is - it
implements `StorageService`, which is what the tests assembling the real
provider graph need.

## Criterion 5: assertions changed

None. No existing test file appears in the merged diff
(`criterion-5-no-assertion-changes.txt`). The existing mocks are

```dart
class MockStorageService extends Mock implements StorageService {}
```

and `StorageService implements IStorageService, IKeyValueStore`, so they still
satisfy the narrowed parameter without an edit. The scoped run is 468 tests,
all passing.

## Files

| File | What it is |
|---|---|
| `format.log`, `analyze.log`, `tests.log` | `run_acceptance.sh 179 --no-goldens` output |
| `criterion-1-grep.txt` | both grep forms plus the declared types in all three data sources |
| `criterion-2-providers.txt` | the two provider bodies and `keyValueStoreProvider`'s definition |
| `criterion-3-4-seam-tests.log` | the six new seam tests, expanded reporter, exit 0 |
| `criterion-5-scoped-tests.log` | `flutter test test/features/tasks/ test/features/feature_flags/`, exit 0 |
| `criterion-5-no-assertion-changes.txt` | merged diff stat, storage-key diff, `lib/core/storage` check |
| `criterion-6-audit.log` | `./scripts/dev/audit_template.sh`, exit 0, 2725 tests |
