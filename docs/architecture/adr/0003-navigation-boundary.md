# ADR 0003: Navigation Boundary

- Status: Proposed
- Date: 2026-03-27

## Context
Presentation code uses `go_router` APIs directly (`context.go`, route extensions). This creates router lock-in and makes navigation behavior harder to test without widget/router integration.

## Decision
Introduce `AppNavigator` as the navigation contract used by presentation logic. Implement `GoRouterNavigatorAdapter` in routing layer and keep `go_router` details there.

Also extract auth redirect policy to a pure service (`AuthRedirectPolicy`) that can be unit tested independently from router internals.

## Consequences
### Positive
- Router implementation can change with lower feature churn.
- Easier unit testing of navigation decisions.
- Cleaner separation of orchestration logic from framework concerns.

### Trade-offs
- Requires migration of existing direct navigation calls.
- Initial boilerplate for route intents and parameter mapping.

## Compatibility Criteria
- Existing route constants remain unchanged during migration.
- `NavigationExtensions` stay as compatibility helpers until all targeted screens are migrated.
