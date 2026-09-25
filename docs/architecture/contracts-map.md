# Contracts and adapter map

This document is the **single map** from **contracts** to **default adapters**, **providers to override**, and **optional modules**.

Every symbol and line number below was checked against `lib/` at `48ba708`. Line
numbers drift; the symbol names are the durable part, and
`grep -rn "<symbol>" lib` is the check.

## Barrel import

For feature and core code that only need types:

- `lib/core/contracts/contracts.dart` exports all boundary contracts.

## Contract files

| Contract | File |
| --- | --- |
| HTTP transport | `lib/core/contracts/network_contracts.dart` (`INetworkClient`, `IHttpResponseCache`, `NetworkRequest`, `NetworkResponse`) |
| Storage | `lib/core/contracts/storage_contracts.dart` (`IKeyValueStore`, `ITokenStore`) |
| Navigation | `lib/core/contracts/navigation_contracts.dart` (`AppNavigator`) |
| Design tokens | `lib/core/contracts/design_tokens_contracts.dart` (`AppDesignTokens`) |
| Presentation controllers | `lib/core/contracts/state_boundary_contracts.dart` (`IAuthController`, `ITasksController`, `ISessionTerminationSink`, and the `*StateSnapshot` marker types) |

## Swap map (default wiring)

**Read the Status column before you plan a swap.** Four of the rows below are not
load-bearing today: `AppNavigator`, `AppDesignTokens` and `IAuthController` are
declared and implemented but no production code consumes them, and
`ITasksController` has no implementor at all. For those four, following the
"To replace" column changes nothing at runtime until a consumer exists. Whether
they should be wired up or deleted is an open question, not a settled one - see
koniz-dev/flutter-starter#64 and its children.

| Status | Means |
| --- | --- |
| **Live** | Production code in `lib/` is typed on the contract and runs against it. Swapping the implementation changes behavior. |
| **No production consumer** | An implementation exists, and for some rows a provider binds it to the contract, but nothing in `lib/` reads that binding. Tests may. Swapping the implementation changes nothing until a consumer exists. |
| **No implementor** | The contract is declared and nothing anywhere implements it. |

| Contract / surface | Status | Default implementation | Wired in / consumed by | To replace |
| --- | --- | --- | --- | --- |
| `INetworkClient` | **Live** | `DioNetworkClient` (`lib/core/network/adapters/dio_network_client.dart:5`) | Field typed on the contract in `ApiClient` (`lib/core/network/api_client.dart:138`), bound to `DioNetworkClient` at `:54`; every `ApiClient` verb method routes through `_send` (`:259`), which calls `_networkClient.send` at `:263`. The public `networkClient` getter (`:154`) has no readers. | No provider binds it: edit `ApiClient`, or supply your own `AuthRemoteDataSource` |
| `ApiClient` (concrete class, not a contract) | **Live** | Dio + interceptors | `apiClientProvider` (`lib/core/di/providers.dart:107`); `networkClientProvider` (`:35`) is a typed alias of the same instance, read at `lib/features/auth/di/auth_providers.dart:41` | Override `apiClientProvider`, or replace feature datasources if you drop Dio |
| `IHttpResponseCache` | **Live** | `CacheInterceptor` (`lib/core/network/interceptors/cache_interceptor.dart:60`) | Exposed as `ApiClient.responseCache` (`lib/core/network/api_client.dart:160`); held by `AuthInterceptor` (`lib/core/network/interceptors/auth_interceptor.dart:118`) and by `AuthRepositoryImpl` (`lib/features/auth/data/repositories/auth_repository_impl.dart:34`), wired at `lib/features/auth/di/auth_providers.dart:63` | Implement the contract and pass it where `CacheInterceptor` is constructed |
| `IKeyValueStore` | **Live** | `StorageService` (`lib/core/storage/storage_service.dart:47`) | `keyValueStoreProvider` (`lib/core/di/providers.dart:23`), read at `lib/features/auth/di/auth_providers.dart:28` and `:88`, `lib/features/tasks/di/tasks_providers.dart:19`, `lib/features/feature_flags/presentation/providers/feature_flags_providers.dart:18`; fields typed on the contract at `lib/features/auth/data/datasources/auth_local_datasource.dart:54`, `lib/features/tasks/data/datasources/tasks_local_datasource.dart:45`, `lib/features/feature_flags/data/datasources/feature_flags_local_datasource.dart:30` | Provider override to your store |
| `ITokenStore` | **Live** | `SecureTokenStore` (`lib/core/storage/adapters/secure_token_store.dart:6`) | `tokenStoreProvider` (`lib/core/di/providers.dart:28`), read at `lib/features/auth/di/auth_providers.dart:29` and `:82`; fields typed on the contract at `lib/core/network/interceptors/auth_interceptor.dart:52` and `lib/features/auth/data/datasources/auth_local_datasource.dart:57` | Provider override |
| `ISessionTerminationSink` | **Live** | `RiverpodSessionTerminationSink` (`lib/features/auth/presentation/providers/auth_provider.dart:272`) | Passed to `AuthInterceptor` at `lib/features/auth/di/auth_providers.dart:93`; held at `lib/core/network/interceptors/auth_interceptor.dart:87` and invoked on forced logout at `:534` | Implement the contract and pass it in the same place |
| `AppNavigator` | **No production consumer** | `GoRouterNavigatorAdapter` (`lib/core/routing/adapters/go_router_navigator_adapter.dart:6`) | `appNavigatorProvider` (`lib/core/routing/navigation_providers.dart:7`). Its only reader is `test/core/routing/navigation_providers_test.dart:25`; screens call GoRouter directly. | A new adapter implementing `AppNavigator` **and** a consumer - overriding the provider alone changes nothing today |
| `AppDesignTokens` | **No production consumer** | `DefaultDesignTokens` (`lib/shared/design_system/tokens/default_design_tokens.dart:9`) | Nowhere, and there is no provider. `AppTheme` binds the **concrete** class at compile time: `static const _tokens = DefaultDesignTokens();` (`lib/shared/theme/app_theme.dart:7`). Nothing in `lib/` is typed on `AppDesignTokens`. | Edit `lib/shared/theme/app_theme.dart` to construct your own token class (and update the theme building that reads `_tokens`). There is no override point. |
| `IAuthController` | **No production consumer** | `AuthNotifier` (`lib/features/auth/presentation/providers/auth_provider.dart:47`) | `authControllerProvider` (`lib/features/auth/presentation/providers/auth_provider.dart:284`) binds it, but that identifier has **zero readers** in `lib/` and `test/` - the UI reads the generated `authProvider` directly. | Rebinding `authControllerProvider` to your orchestrator has no effect until something reads it |
| `ITasksController` | **No implementor** | none | Nowhere. `TasksNotifier` (`lib/features/tasks/presentation/providers/tasks_provider.dart:55`) does **not** implement this contract, and the tasks provider is `tasksProvider` (alias `tasksNotifierProvider`, `:195`). | Implement the contract on `TasksNotifier` first; there is nothing to rebind today |

Until koniz-dev/flutter-starter#182 the `ITasksController` row named a controller
provider that has never existed anywhere in the tree - the name is deliberately
not repeated here, so that grepping for it stays a clean test. **If you add or
edit a row, `grep -rn "<symbol>" lib` every symbol you put in it.** A symbol whose
only occurrence in the repository is this file is the tell.

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
| Remote feature flags | `NoOpFeatureFlagsRemoteDataSource` (`lib/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart:24`) | **No Firebase implementation ships in this repository.** Write your own `FeatureFlagsRemoteDataSource` (contract at the same file, `:6`) | Override `featureFlagsRemoteDataSourceProvider`, generated from the `@riverpod featureFlagsRemoteDataSource` function at `lib/features/feature_flags/presentation/providers/feature_flags_providers.dart:23` |
| RASP | `NoOpRaspService` | `freerasp` (when you wire it) | `raspServiceProvider` in `lib/core/security/rasp_providers.dart` |
| Firebase Performance | No-op via performance providers | Firebase SDK | `lib/core/performance/performance_providers.dart` (see comments there) |
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
