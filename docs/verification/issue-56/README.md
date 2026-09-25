# Acceptance evidence - issue #56

`fix(routing): tasks routes are unreachable, popUntilRoute pops the whole
stack, and back() falls back to /login`

Change merged as `7b24e4c` (PR #123). Evidence below was regenerated against
`dd0e6af`, the current `main`, so it reflects the tree as it stands after
`#85` (`0f1f570`), `#114` (`4e32f40`) and `#126` (`cd56d01`) landed on top.

## Per-criterion result

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | Register the tasks and feature-flags routes, or delete the dead constants. Note the strip-tool interaction. | PASS - option (a), registered | [`criteria-1-5-6-static-checks.log`](criteria-1-5-6-static-checks.log) sections 1a/1b; [`criterion-1-routes-reachable.log`](criterion-1-routes-reachable.log); [`criterion-1-strip-variants.log`](criterion-1-strip-variants.log) |
| 2 | `app_router.dart` defines an `errorBuilder`; a test asserts it for an authenticated user on an unknown path. | PASS | [`criterion-2-error-builder.log`](criterion-2-error-builder.log) |
| 3 | `popUntilRoute` leaves the user on the target, not at the bottom of the stack; the test asserts the resulting location. | PASS, with a documented deviation (see below) | [`criterion-3-pop-until-route.log`](criterion-3-pop-until-route.log) plus the negative control [`criterion-3-REGRESSION-DEMO.log`](criterion-3-REGRESSION-DEMO.log) |
| 4 | `GoRouterNavigatorAdapter.back()` with an empty stack goes home; the adapter test is updated. | PASS | [`criterion-4-adapter-back.log`](criterion-4-adapter-back.log) |
| 5 | The six assertion-free tests assert their outcome, and `navigation_extensions_test.dart` drives the app's router. | PASS | [`criteria-1-5-6-static-checks.log`](criteria-1-5-6-static-checks.log) sections 5a/5b/5c; [`criterion-3-pop-until-route.log`](criterion-3-pop-until-route.log) |
| 6 | The `expect(router, isNotNull)` / `expect(RouteParams, isNotNull)` tautologies are replaced with real assertions. | PASS | [`criteria-1-5-6-static-checks.log`](criteria-1-5-6-static-checks.log) section 6 |
| 7 | `./scripts/dev/audit_template.sh` exits 0. | PASS | [`criterion-7-audit_template.log`](criterion-7-audit_template.log) |

## Criterion 3 - what was asserted instead, and why

The criterion names the stack `/` -> `/login` -> `/register`. **That stack
cannot exist in this app**, because of the auth guard #51 added:

- unauthenticated, `/` redirects to `/login` before it ever renders, so the
  bottom entry is never `/`;
- authenticated, pushing `/login` is redirected straight back to `/`, so the
  middle entry is never `/login`.

The guard was left untouched. Three deep is the minimum depth that tells a
correct `popUntilRoute` apart from one that pops until it cannot - at two deep
both land in the same place - so the test asserts the reachable three-deep
equivalent `/login` -> `/register` -> `/login`, popping to `/register`, and the
tasks routing test adds the authenticated `/` -> `/tasks` -> `/tasks/:id`
case. `criterion-3-REGRESSION-DEMO.log` shows the new test failing against the
pre-fix implementation, which is what makes the assertion meaningful.

## #51's redirect machinery still works

`no-regression-51-redirect-machinery.log` runs
`test/features/auth/session_restore_test.dart` on the merged tree. Both of the
properties #51 exists for still hold:

- `restore in flight does not flash /login, then lands on /` - the no-flash
  hold state;
- `deep link survives the login round trip (#51) bounce to /login carries the
  destination, and returns to it`, plus
  `an off-site redirect target is ignored` - the round trip and its
  open-redirect guard.

#56 only added an `errorBuilder` argument above the `redirect` callback; it
changed no line of the guard, `_loginPreserving` or `_destinationAfterAuth`.
Note the ordering consequence, documented in the routing guide: an
*unauthenticated* user hitting an unknown path is still bounced to `/login`
before the router looks for a match, so the new 404 is only reachable once
signed in - which is why criterion 2's test authenticates first.

## The PNGs prove nothing here - do not cite them

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into this
directory whether or not the issue is visual. All eight were opened and
inspected by the closing session: they show the login screen, the home screen,
the failed-logout states, the startup-failure screen and the light/dark theme
swatches. **None of them renders any surface this issue touched** - no tasks
list, no task detail, no feature-flags debug screen, no 404 screen.

[`goldens-checksums.txt`](goldens-checksums.txt) shows every copy here matching
its `test/acceptance/goldens/` original byte for byte, so this run changed no
golden. **No row in the table above rests on a PNG.** Criterion 2's claim is
specifically about wording (`Page not found`, `The page you are looking for
does not exist.`, `Back to home`), which a golden can never show, since
`flutter test` renders every glyph as an opaque block - it is asserted with
`find.text()` instead.

## Files

| File | What it is |
|---|---|
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | the four `run_acceptance.sh` gates, all exit 0 |
| `criterion-1-routes-reachable.log` | the two new feature routing suites + the registry test |
| `criterion-1-strip-variants.log` | all three `strip_sample_features.dart` variants applied, analyzed and tested |
| `criterion-2-error-builder.log` | `app_router_test.dart`, including the `errorBuilder` group |
| `criterion-3-pop-until-route.log` | `navigation_extensions_test.dart` against the app's router |
| `criterion-3-REGRESSION-DEMO.log` | negative control: the same test against the pre-fix `popUntilRoute` (**fails, as intended**) |
| `criterion-4-adapter-back.log` | `go_router_navigator_adapter_test.dart` |
| `criteria-1-5-6-static-checks.log` | greps for the registry wiring, the local-router removal and the tautologies, contrasted with `7b24e4c^` |
| `criterion-7-audit_template.log` | `./scripts/dev/audit_template.sh`, exit 0 |
| `no-regression-51-redirect-machinery.log` | #51's no-flash guard and deep-link round trip still pass |
| `goldens-checksums.txt` | proof the copied PNGs are the unchanged repository goldens |
| `*.png` | the standing acceptance goldens. Unrelated to this issue - see above |
