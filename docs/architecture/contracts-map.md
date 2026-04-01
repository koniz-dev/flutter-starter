# Contracts and adapter map

This document is the **single map** from **contracts** to **default adapters**, **providers to override**, and **optional modules**.

## Barrel import

For feature and core code that only need types:

- `lib/core/contracts/contracts.dart` exports all boundary contracts.

## Contract files

| Contract | File |
| --- | --- |
| HTTP transport | `lib/core/contracts/network_contracts.dart` (`INetworkClient`, `NetworkRequest`, …) |
| Storage | `lib/core/contracts/storage_contracts.dart` (`IKeyValueStore`, `ITokenStore`) |
| Navigation | `lib/core/contracts/navigation_contracts.dart` (`AppNavigator`) |
| Design tokens | `lib/core/contracts/design_tokens_contracts.dart` (`AppDesignTokens`) |
| Presentation controllers | `lib/core/contracts/state_boundary_contracts.dart` (`IAuthController`, `ITasksController`, …) |

## Swap map (default wiring)

| Contract / surface | Default implementation | Wired in | To replace |
| --- | --- | --- | --- |
| `INetworkClient` | `DioNetworkClient` | Constructed inside `ApiClient` (`networkClient` getter) | Swap by replacing `ApiClient` construction or providing a custom `AuthRemoteDataSource` |
| `ApiClient` | Dio + interceptors | `apiClientProvider`; `networkClientProvider` is a typed alias of the same instance | Override `apiClientProvider` / replace feature datasources if you drop Dio |
| `IKeyValueStore` | `StorageService` | `keyValueStoreProvider` | Provider override to your store |
| `ITokenStore` | `SecureTokenStore` | `tokenStoreProvider` | Provider override |
| `AppNavigator` | `GoRouterNavigatorAdapter` | `appNavigatorProvider` in `lib/core/routing/navigation_providers.dart` | New adapter implementing `AppNavigator` |
| `AppDesignTokens` | `DefaultDesignTokens` | Consumed by `AppTheme` in `lib/shared/theme/app_theme.dart` | Swap token class + theme building |
| `IAuthController` | `AuthNotifier` via `authControllerProvider` | `lib/features/auth/presentation/providers/auth_provider.dart` | Rebind `authControllerProvider` to your orchestrator |
| `ITasksController` | `TasksNotifier` via `tasksControllerProvider` | `lib/features/tasks/presentation/providers/tasks_provider.dart` | Rebind or remove feature if stripped |

## Adapter directories (convention)

| Kind | Directory |
| --- | --- |
| Network | `lib/core/network/adapters/` |
| Storage | `lib/core/storage/adapters/` |
| Routing | `lib/core/routing/adapters/` |
| Theme | Prefer tokens in `lib/shared/design_system/` + `lib/shared/theme/app_theme.dart` |
| State | Notifiers under `lib/features/*/presentation/providers/` implementing controller contracts |

## Optional modules

| Module | Default | Concrete / notes | Override or template |
| --- | --- | --- | --- |
| Remote feature flags | `NoOpFeatureFlagsRemoteDataSource` | Firebase: `FirebaseFeatureFlagsRemoteDataSource` | `featureFlagsRemoteDataSourceProvider` in `lib/features/feature_flags/presentation/providers/feature_flags_providers.dart` |
| RASP | `NoOpRaspService` | `freerasp` (when you wire it) | `raspServiceProvider` in `lib/core/security/rasp_providers.dart` |
| Firebase Performance | No-op via performance providers | Firebase SDK | `performance_providers.dart` (see comments there) |
| Crashlytics logging | Template output | `lib/core/logging/crashlytics_output_template.dart` | Wire into logging pipeline when needed |
| GraphQL | Template | `lib/core/network/graphql_client_template.dart` | Copy/adapt; keep REST behind `INetworkClient` |
| Isar / local DB | Template + interface | `lib/core/storage/isar_database_template.dart`, `local_database.dart` | Opt-in persistence |
| Patrol E2E | Dev dependency | `integration_test/` | Optional flows |

**Stripped starter:** `dart run tool/strip_sample_features.dart --apply` removes the sample `tasks` and `feature_flags` modules. Rows above that reference those paths describe the **full** tree only; after strip, use `tool/golden/stripped/` as the rewired baseline.

## Dependency direction

- Features depend on **contracts** and **domain**, not on vendor SDKs in domain.
- Adapters depend on **contracts + vendor**.
- Composition root (`lib/core/di/providers.dart`, `main.dart`, feature DI files) **binds** implementations.

## Related

- [Super starter hub](super-starter-hub.md)
- [Choose your stack](choose-your-stack.md)
- [Quality gates and risks](migrations/quality-gates-and-risks.md)
