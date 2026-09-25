# Verification evidence - koniz-dev/flutter-starter#142

Commit under test: `997e100` (PR #172, squash-merged to `main`).

`StorageDowngradeException` and `MigrationPathException` inherited
`MigrationExecutionException.toString()`, which hardcoded the parent's name. The
base class now formats through an overridable `exceptionName`, which each
subclass overrides.

Not `runtimeType`: `very_good_analysis` raises `no_runtimetype_tostring` on it
(reproduced during implementation), and the release builds documented in
`docs/guides/security/implementation.md` pass `--obfuscate`, which would reduce
`runtimeType` to a minified token in exactly the situation this string exists
for - a user-visible startup failure.

## What proves what

| Criterion | Artifact | What it establishes |
|---|---|---|
| 1 | `criteria-1-2-tostring-tests.log` | `exception toString (#142)` group passes. `a downgrade refusal names itself, not its parent` asserts `StorageDowngradeException(...).toString()` both `startsWith('StorageDowngradeException:')` and equals `'StorageDowngradeException: boom'`; the `MigrationPathException` case is the mirror of it. Both live in `test/core/storage/migration/migration_executor_test.dart`. |
| 1 | `criteria-1-2-tostring-tests.log` | The same run covers the two **throw-site** assertions added to the `#60` groups: the objects the executor really throws now carry `toString` matchers, so a regression fails where it is produced. |
| 2 | `criteria-1-2-tostring-tests.log` | `the base class names itself and keeps its original-exception line` asserts the base equals `'MigrationExecutionException: boom'`, and with `originalException` equals `'MigrationExecutionException: boom\nOriginal exception: Bad state: inner'`. The pre-existing `#60` tests in the same file still pass. |
| 3 | `criterion-3-reachability.log` | `a downgrade refusal boots into the failure screen` passes with the assertion switched back to `find.textContaining('StorageDowngradeException')`; the explanatory comment is gone. `a failed version stamp boots into the failure screen`, which matches `MigrationExecutionException`, still passes - so the two cases again assert two *different* class names. |
| 4 | `audit_template.log` | `./scripts/dev/audit_template.sh` on merged `main`: env asset guard, format, `flutter analyze` ("No issues found!"), `flutter test` 2691 passed / 8 skipped. Exit 0. |
| - | `prefix-regression-repro.log` | The **contrast run**. The new tests against `origin/main`'s unmodified `migration_executor.dart`: 5 fail. |
| - | `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `run_acceptance.sh 142` on merged `main`. |
| - | `goldens-checksums.txt` | Every copied PNG is byte-identical to its `test/acceptance/goldens/` original. |

## The contrast run is the point

`prefix-regression-repro.log` shows the defect, and shows why it was worth
fixing at the throw site rather than only on screen. Against the old code:

- `exception toString (#142) a downgrade refusal names itself, not its parent`
  fails with `Expected: a string starting with 'StorageDowngradeException:'` /
  `Actual: 'MigrationExecutionException: boom'`. Unambiguous.
- `MigrationExecutor downgrade detection (#60) throws distinctly when stored
  version is newer` fails naming the real user-facing string:
  `'MigrationExecutionException: Stored data is at version 3 but this build
  only supports version 2. Refusing to read newer data with older code.'`
- The widget test fails with `Found 0 widgets with text containing
  StorageDowngradeException: []` - the exact failure mode reported in the issue,
  which reads as "the wrong screen rendered" rather than "the class name is the
  parent's".

The first two are the reason the throw-site assertions were added.

## What the PNGs do NOT prove

`run_acceptance.sh` copies all 13 standing goldens in. **No criterion here rests
on any of them.** This issue changes one string and two test files; nothing it
touches renders. `goldens-checksums.txt` pairs every copied PNG with its
`test/acceptance/goldens/` original at the same SHA-256, so the run introduced
no golden regression either.

All 13 were opened and inspected. Nine are distinct; the other four are
byte-identical duplicates (`cold_start_stale_user_no_token.png` and
`forced_logout_after.png` match `cold_start_no_session.png`;
`failed_logout_before_home.png` and `forced_logout_before.png` match
`cold_start_restored_session.png`).

`startup_failure.png` is the one worth naming, because it is the screen this
issue is about. It genuinely renders `StartupFailureApp` - icon, title, body,
Try again button - but **it cannot prove anything here**: `flutter test` renders
text with the Ahem font, so every glyph is an opaque black block. The error
string on it is unreadable, and a class name is precisely wording. The class
name is asserted with `find.textContaining()` in
`criterion-3-reachability.log`, never read off a screenshot.
