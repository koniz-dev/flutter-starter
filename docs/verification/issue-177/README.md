# Issue #177 - one navigation style; `AppNavigator` deleted

Verified against `main` after PR #201 merged as `b3ec85a`. Evidence collected at
`a3c061a` (the first commit on `main` after the merge).

## The decision

`AppNavigator` was **deleted**, not wired. `NavigationExtensions`
(`lib/core/routing/navigation_extensions.dart`) is the one navigation API
presentation code calls, and `package:go_router` is now imported only inside
`lib/core/routing/` and in the four `lib/features/*/routing/*_routes.dart`
modules that declare routes.

The rejected alternative - keep the contract and route the screens through
`appNavigatorProvider` - is recorded with its reasons in
[`docs/architecture/adr/0003-navigation-boundary.md`](../../architecture/adr/0003-navigation-boundary.md)
and in the PR body of #201. In short: it adds a second boundary over the same
package rather than removing one, it navigates through the global
`goRouterProvider` without the caller's `BuildContext`, and adopting it fully
meant deleting the tested, context-aware `NavigationExtensions`.

## Result

| Criterion | Result | Evidence |
|---|---|---|
| 1. `grep -rn "package:go_router" lib \| grep -v "^lib/core/routing/"` returns exactly the four `*_routes.dart` modules | PASS | [`criterion-1-go-router-imports.log`](criterion-1-go-router-imports.log) |
| 2. The three screens navigate through the same API `tasks_list_screen.dart` uses; no screen calls `context.go` / `context.pop` from `package:go_router` | PASS | [`criterion-2-screen-navigation-api.log`](criterion-2-screen-navigation-api.log) |
| 3. `AppNavigator` resolved one way or the other - **deleted**: contract, adapter, provider and both tests are gone | PASS | [`criterion-3-appnavigator-deleted.log`](criterion-3-appnavigator-deleted.log) |
| 4. `grep -rn "AppNavigator" docs/` produces no statement contradicting the tree; the contracts map and ADR 0003 describe what happened | PASS | [`criterion-4-docs-consistent.log`](criterion-4-docs-consistent.log) |
| 5. Navigation behaviour unchanged, proved by two widget tests (login -> register by `UiKeys` key; task detail -> tasks list) | PASS | [`criterion-5-navigation-behaviour.log`](criterion-5-navigation-behaviour.log) |
| 6. If the import-rule guard test exists, its allowlist no longer names the three screens and `flutter test test/tooling/` exits 0 | PASS (vacuous on the first clause) | [`criterion-6-tooling.log`](criterion-6-tooling.log) |
| 7. `./scripts/dev/audit_template.sh` exits 0 | PASS | [`criterion-7-audit_template.log`](criterion-7-audit_template.log) |

### Notes per criterion

**1.** The four hits are `auth_routes.dart:5`, `feature_flags_routes.dart:4`,
`home_routes.dart:4`, `tasks_routes.dart:5`. The log also runs the inverse count
(`grep -vc "/routing/[a-z_]*_routes\.dart:"`), which is `0`.

**2.** The log shows the raw-`go_router` grep returning nothing across
`lib/features/`, then the replacement calls: `context.goToRegister()` in
`login_screen.dart:115`; `context.canPopRoute()` / `context.popRoute<void>()` /
`context.goToLogin()` in `register_screen.dart:139-142`;
`context.canPopRoute()` / `context.popRoute<void>()` in
`task_detail_screen.dart:114-115` and `:156-157`. `tasks_list_screen.dart`
already used `context.pushRoute(...)` and is unchanged.

**3.** `grep -rn "AppNavigator\|appNavigatorProvider\|GoRouterNavigatorAdapter"
lib test` returns nothing, all five files are absent from the working tree, and
the log includes the `git log --diff-filter=D` entry for `b3ec85a` naming each
deletion. `contracts.dart` no longer exports `navigation_contracts.dart`.

**4.** Five remaining `AppNavigator` mentions in `docs/`, all describing the
deletion (ADR 0003's context, decision and rejected-alternative sections; the
migration plan's phase B note; the contracts map's status preamble). No doc
points at a deleted path. `dart run tool/check_docs.dart` exits 0 - 644 relative
links resolve.

**5.** Three tests, all passing:

- `test/core/routing/screen_navigation_test.dart`
  - *login screen link renders the register screen* - pumps the real router at
    `/login` via `pumpAppRouter` in `test/helpers/pump_app.dart`, taps the
    register `TextButton`, asserts the location is `/register` and that
    `find.byKey(UiKeys.registerSubmit)` finds one widget. That is the
    "found by a key from `lib/core/constants/ui_keys.dart`" the criterion asks
    for.
  - *register screen link returns to the login screen* - covers the
    `canPopRoute` fallback branch (`go` leaves nothing to pop), asserting
    `UiKeys.loginSubmit` renders afterwards.
- `test/features/tasks/presentation/screens/task_detail_navigation_test.dart`
  - *task detail returns to the tasks list after saving* - pushes
    `/tasks/task-1` exactly the way `tasks_list_screen.dart` does, taps save,
    and asserts `TaskDetailScreen` is gone and `TasksListScreen` renders at
    `/tasks`.

The tasks test lives under `test/features/tasks/` because
`tool/strip_sample_features.dart` deletes that directory with the feature; a
test under `test/core/routing/` importing tasks screens would break the
`stripped` and `no_tasks` strip-smoke variants. All three strip variants passed
on PR #201.

**6.** The import-rule guard test does not exist - `test/tooling/` holds only
`check_env_assets_test.dart`, and nothing under `test/tooling/` names the three
screen files. The criterion's condition ("if the guard test exists") is
therefore not met, and its second clause is satisfied anyway:
`flutter test test/tooling/` passes 33 tests, exit 0. Building the guard is a
separate #64 child, not this issue.

**7.** `./scripts/dev/audit_template.sh` exits 0: env asset guard, format
(0 changed), `flutter analyze` (no issues), `flutter test` (2735 passed,
8 skipped).

## No regression in the #51 / #56 routing work

[`no-regression-51-redirect-machinery.log`](no-regression-51-redirect-machinery.log)
runs `test/features/auth/session_restore_test.dart` together with the whole
`test/core/routing/` suite: 72 tests, exit 0. That covers the three-state auth
guard that holds the requested location while `sessionRestorationProvider`
loads, the `_loginPreserving()` / `_destinationAfterAuth()` deep-link round trip
including the off-site-redirect rejection, the `#56` `errorBuilder` 404, and
`popUntilRoute`. `lib/core/routing/app_router.dart` was not touched by this
change.

## The PNGs prove nothing about this issue

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into this
directory, so 13 screenshots ship here that have nothing to do with navigation
style. They are byte-identical to the committed goldens - see
[`goldens-checksums.txt`](goldens-checksums.txt), where every hash appears twice
(once per directory). The run left them untouched and **no criterion above rests
on them**.

Each was opened and inspected. They are the standing #51 cold-start goldens
(login and home screens), the forced/failed logout pair, the list-view empty and
error states, the startup failure screen, and the light/dark typography
specimens. Remember `flutter test` renders text with the Ahem font, so every
glyph is an opaque block: these cannot show wording, and none of them is cited
as evidence.

## Harness logs

`analyze.log`, `format.log`, `tests.log` and `goldens.log` are the raw output of
`./scripts/test/run_acceptance.sh 177`; all four exit 0.
