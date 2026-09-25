# ADR 0003: Navigation Boundary

- Status: Accepted
- Date: 2026-09-25 (supersedes the Proposed version of 2026-03-27)

## Context
Presentation code navigated through three different APIs at once: the
`NavigationExtensions` extension on `BuildContext`
(`lib/core/routing/navigation_extensions.dart`), raw `context.go` / `context.pop`
from `package:go_router`, and an `AppNavigator` contract with a
`GoRouterNavigatorAdapter` behind `appNavigatorProvider`. Three answers to "how
do I navigate here", and the one this ADR originally proposed had **zero**
production consumers: `appNavigatorProvider` was read only by its own test.

A starter template has to answer this once. Router lock-in is a real cost, but
the cost is only paid once per navigation *boundary*, not once per boundary
style.

## Decision
`NavigationExtensions` is the single navigation API for presentation code, and
`lib/core/routing/` is the only place `package:go_router` may be imported -
alongside the four designated `lib/features/*/routing/*_routes.dart` modules,
which declare routes rather than perform navigation.

Screens call `context.goToRegister()`, `context.pushRoute(...)`,
`context.popRoute()`, `context.canPopRoute()`, `context.popOrGoToHome()`. They
do not import `package:go_router`.

The `AppNavigator` contract, `GoRouterNavigatorAdapter` and
`appNavigatorProvider` were **deleted** (koniz-dev/flutter-starter#177).

The auth redirect policy decision from the original ADR stands and is
implemented: `app_router.dart` holds the redirect, including the three-state
guard that parks the requested location while `sessionRestorationProvider` is
in flight, and the `redirect` query-parameter round trip with its open-redirect
guard.

## Rejected alternative: wire `AppNavigator` instead
Keeping the contract and routing the screens through `appNavigatorProvider` was
the other way to satisfy "one navigation style". It was rejected because:

- It does not remove a boundary, it adds a second one. `NavigationExtensions`
  already confines `go_router` to `lib/core/routing/`, which is the property
  the ADR wanted. Two boundaries over the same package is the problem, not the
  fix.
- `appNavigatorProvider` resolves the *global* `goRouterProvider`, so it
  navigates without the caller's `BuildContext`. `NavigationExtensions` methods
  such as `popUntilRoute` and `popOrGoToHome` are context-aware and carry
  behaviour the adapter would have had to re-grow.
- Adopting it fully meant migrating `tasks_list_screen.dart` off
  `pushRoute` and deleting `NavigationExtensions` - a much larger change that
  would discard tested behaviour to gain an indirection nothing had asked for.

## Consequences
### Positive
- One navigation style, mechanically checkable: no `package:go_router` import
  outside `lib/core/routing/` and the four `*_routes.dart` modules.
- Three files fewer, and no contract advertised in the docs that nothing uses.
- The swap story is unchanged in substance: replacing the router means
  rewriting `navigation_extensions.dart` plus the route modules, in one place.

### Trade-offs
- Navigation is an extension on `BuildContext`, so it cannot be injected or
  faked through a provider override. Navigation tests pump the real router -
  see `test/core/routing/navigation_extensions_test.dart` and
  `test/core/routing/screen_navigation_test.dart`, which is what catches a
  helper pointing at an unregistered route.
- Presentation code is typed on a repository-owned extension rather than on an
  abstract class. Swapping routers is a rewrite of that one file rather than a
  new implementation of an interface.

## Compatibility Criteria
- Route constants in `AppRoutes` are unchanged.
- No screen imports `package:go_router`; adding one is the regression to watch
  for.
