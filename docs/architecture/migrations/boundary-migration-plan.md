# Boundary Migration Plan (Storage, Navigation, Theme, State)

## Dependency Order
1. Storage boundary
2. Navigation boundary
3. Theme/token boundary
4. State boundary

This order avoids blocked migrations caused by upstream contracts not ready.

## Phase A: Storage boundary migration

### A1 - Introduce adapters
- Add `IKeyValueStore` + `ITokenStore` adapters around current services.
- Keep `StorageService` and `SecureStorageService` providers active.

### A2 - Auth and interceptor migration
- Refactor auth repository and auth interceptor to use `ITokenStore`.
- Preserve storage migration compatibility in `StorageMigrationService`.

### A3 - Cleanup
- Mark direct secure storage usage in auth/network paths as deprecated.

Rollback strategy:
- Rebind DI providers back to legacy concrete services.

## Phase B: Navigation boundary migration

Done. The `AppNavigator` contract this phase originally proposed was deleted instead of wired; `NavigationExtensions` is the navigation boundary. See [adr/0003-navigation-boundary.md](../adr/0003-navigation-boundary.md) for the decision and the rejected alternative.

### B1 - One navigation API
- `NavigationExtensions` (`lib/core/routing/navigation_extensions.dart`) is the only API presentation code calls.

### B2 - Migrate orchestration points
- Direct `context.go/push/pop` usage removed from screens.
- Auth redirect logic lives in `app_router.dart` (session-restore hold state, `redirect` round trip, open-redirect guard).

### B3 - Cleanup
- `package:go_router` is imported only under `lib/core/routing/` and in the `lib/features/*/routing/*_routes.dart` modules that declare routes.

Rollback strategy:
- Re-import `go_router` in the affected screens; the route table is unchanged.

## Phase C: Theme/token migration

### C1 - Token authority
- Set `shared/design_system/tokens` as source-of-truth.
- Define adapters from token contracts to `ThemeData`.

### C2 - Gradual mapping
- Migrate `shared/theme` values to consume token contracts.
- Add guidelines to prevent direct hardcoded styles in new widgets.

### C3 - Cleanup
- Deprecate duplicate token constants in legacy paths.

Rollback strategy:
- Keep legacy theme constants; revert adapter mapping commits only.

## Phase D: State boundary migration

### D1 - Controller interfaces
- Define `IAuthController`. (`ITasksController` was defined and then deleted
  unimplemented by koniz-dev/flutter-starter#180; the tasks slice keeps its
  boundary as `TasksNotifier`'s own public API.)
- Keep Riverpod notifiers as adapter implementations.

### D2 - Feature migration
- Migrate one feature first (Auth), then Tasks.
- Ensure UI consumes controller contracts in orchestration points.

### D3 - Cleanup
- Limit direct provider API usage to adapters/composition files.

Rollback strategy:
- Rewire UI to existing notifiers for affected feature only.

## Cross-phase Verification
- Feature behavior parity checks after each phase.
- No broad “big-bang” migration commits.
- Release in small slices with isolated blast radius.
