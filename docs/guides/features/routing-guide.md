# Routing Guide

This guide describes the starter routing approach using `go_router` and route
constants from `AppRoutes`.

## Routing Layout

Core routing files:

```text
lib/core/routing/
├── app_routes.dart                 # Route names and paths
├── app_router.dart                 # GoRouter setup + auth redirect
├── routes_registry.dart            # Composes routes from feature modules
├── navigation_providers.dart       # AppNavigator provider
└── adapters/go_router_navigator_adapter.dart
```

Feature route modules (convention):

```text
lib/features/<feature>/
└── routing/
    └── <feature>_routes.dart
```

A constant in `AppRoutes` is not a route. Add the feature's `routing/` module
to `buildAppRoutes` in the same change that adds the constant, or the helper
that uses it resolves to nothing and the user lands on the 404 below. Cover it
with a widget test that pumps `goRouterProvider` and asserts the destination
screen renders - a test that builds its own `GoRouter` proves only that
`go_router` works.

## Navigate in UI

Use `GoRouter` directly in screens/widgets:

```dart
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:go_router/go_router.dart';

context.go(AppRoutes.home);
context.push(AppRoutes.tasks);
context.pushNamed(
  AppRoutes.taskDetailName,
  pathParameters: {'taskId': 'task-123'},
);
```

## Route Constants

Always use constants from `AppRoutes` instead of hardcoded paths.

```dart
// Good
context.go(AppRoutes.login);

// Avoid
context.go('/login');
```

## Authentication Redirect

Auth redirect lives in `goRouterProvider` and decides:

- unauthenticated user -> auth routes only
- authenticated user -> app routes

Keep redirect logic synchronous and based on lightweight auth snapshot checks.

## Unmatched Routes

`goRouterProvider` sets an `errorBuilder` that renders `RouteNotFoundScreen`
(`lib/core/routing/route_not_found_screen.dart`): a localized 404 naming the
location, with a button back to home. Without it go_router shows its own debug
page, which prints the framework exception at the user.

Note the interaction with the auth redirect: an *unauthenticated* user hitting
an unknown path is bounced to `/login` before the router ever looks for a
match, so the 404 is only visible once signed in.

## Deep Links

`go_router` supports deep links out of the box. Your app-specific platform
configuration (Android/iOS/web) should map incoming URLs to defined route paths.

## Best Practices

1. Keep redirect + router creation centralized in `app_router.dart`.
2. Keep per-feature route trees in feature route modules, then compose in `routes_registry.dart`.
3. Prefer named routes for dynamic path segments.
4. Use query params for optional filters and sort values.
5. Keep navigation decisions in presentation layer; avoid routing in domain.
6. Add widget tests for important navigation flows (auth gate, detail screens)
   against the app's router, not a locally built one.

## Troubleshooting

- Wrong screen opens: verify route path and `AppRoutes` constant mapping.
- Redirect loops: confirm auth state transitions and redirect conditions.
- `pop` fails on root: check `canPop()` before popping or provide fallback route.

## References

- [GoRouter docs](https://pub.dev/documentation/go_router/latest/)
- [Architecture ADR - Navigation Boundary](../../architecture/adr/0003-navigation-boundary.md)
