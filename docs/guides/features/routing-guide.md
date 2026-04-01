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

## Deep Links

`go_router` supports deep links out of the box. Your app-specific platform
configuration (Android/iOS/web) should map incoming URLs to defined route paths.

## Best Practices

1. Keep redirect + router creation centralized in `app_router.dart`.
2. Keep per-feature route trees in feature route modules, then compose in `routes_registry.dart`.
2. Prefer named routes for dynamic path segments.
3. Use query params for optional filters and sort values.
4. Keep navigation decisions in presentation layer; avoid routing in domain.
5. Add widget tests for important navigation flows (auth gate, detail screens).

## Troubleshooting

- Wrong screen opens: verify route path and `AppRoutes` constant mapping.
- Redirect loops: confirm auth state transitions and redirect conditions.
- `pop` fails on root: check `canPop()` before popping or provide fallback route.

## References

- [GoRouter docs](https://pub.dev/documentation/go_router/latest/)
- [Architecture ADR - Navigation Boundary](../../architecture/adr/0003-navigation-boundary.md)
