# Verification evidence - issue #184

test: four test files sit at paths that do not mirror lib/, and two duplicate
tests that already exist

Shipped in PR #248, squash-merged to `main` as `933a32d`. Verified against that
commit.

## Artifacts

| File | What it is |
|---|---|
| `format.log` | `dart format --set-exit-if-changed lib test integration_test tool examples`, exit 0 |
| `analyze.log` | `flutter analyze`, "No issues found!", exit 0 |
| `tests.log` | `flutter test --timeout=5m` on the merged tree, `+2812 ~8`, exit 0 |
| `tests-before.log` | the same command on `origin/main` before the change, `+2813 ~8` |
| `structure.log` | the directory listings and `git diff` that prove criteria 1-4 and 6 |

No PNGs: this change touches no widget, so `run_acceptance.sh` was invoked with
`--no-goldens`. No criterion rests on a golden.

## Criterion 5 - coverage accounting

`flutter test --timeout=5m` summary before: `+2813 ~8`. After: `+2812 ~8`.
Net -1 test, **zero assertions lost**. Every deleted file accounted for:

| Deleted file | Tests | Where its assertions went |
|---|---|---|
| `test/shared/theme/app_colors_test.dart` | 5 | `test/shared/design_system/tokens/app_colors_test.dart`, as 4 new tests. All 12 exact-hex expectations preserved; the old file's separate `should have primary color` and `should have secondary color` tests became one `Primary colors hold their documented values`, which is the entire -1. |
| `test/shared/theme/app_text_styles_test.dart` | 6 | `test/shared/design_system/tokens/app_typography_test.dart`, as 6 new tests. All 12 `fontSize`/`fontWeight` expectations preserved one-for-one. |

11 tests deleted, 10 added. The three *moved* files
(`storage_migration_service_test.dart`, `token_refresh_flow_test.dart`,
`error_handling_flow_test.dart`) kept every test; `git log --follow` shows them
as renames, and `token_refresh_flow_test.dart` changed only in the depth of its
two relative `../helpers/` imports.

Why the surviving token tests needed the merge rather than a plain delete: the
two `test/shared/design_system/tokens/` files asserted only `isA<Color>()` and
`isA<TextStyle>()`. Deleting the `test/shared/theme/` pair outright would have
dropped every concrete value the design system pins.

## Criterion 2 - the premise expired

`go_router_navigator_adapter_test.dart` was already gone before this change.
`lib/core/routing/adapters/` does not exist and
`grep -rn GoRouterNavigatorAdapter lib test` returns 0 lines, because
koniz-dev/flutter-starter#177 deleted the adapter along with `AppNavigator`. The
issue anticipated exactly this ("if the routing child deletes it, item 3
disappears"), so criterion 2 is satisfied by its second branch.

## Criterion 4 - the one home, and the runner that stays separate

Auth integration tests under `test/` now live only in
`test/features/auth/integration/` (`auth_flow_test.dart`,
`token_refresh_flow_test.dart`). `test/integration/` no longer exists.

`error_handling_flow_test.dart` was not moved there: it is not an auth test. Its
subject is `lib/core/errors/` (`DioExceptionMapper` ->
`ExceptionToFailureMapper` -> `Result`) and only one of its six cases touches
auth at all, so it moved to `test/core/errors/`.

`integration_test/auth_flow_test.dart` stays where it is. It is a **Patrol**
test executed by `patrol test` against a device, not by `flutter test`, and
`integration_test/` is the location that runner requires. A different runner is
not a third home for the same suite.
