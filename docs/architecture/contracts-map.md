# Contracts and adapter map

This document is the **single map** from **contracts** to **default adapters**, **providers to override**, and **optional modules**.

Every symbol and line number below was checked against `lib/` at `0e397bf`. Line
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
| Design tokens | `lib/core/contracts/design_tokens_contracts.dart` (`AppDesignTokens`) |
| Presentation controllers | `lib/core/contracts/state_boundary_contracts.dart` (`IAuthController`, `ISessionTerminationSink`, and the `*StateSnapshot` marker types) |

## Swap map (default wiring)

**Read the Status column before you plan a swap.** Two of the rows below are not
load-bearing today: `AppDesignTokens` and `IAuthController` are declared and
implemented but no production code consumes them. For those two, following the
"To replace" column changes nothing at runtime until a consumer exists.

That is no longer an open question.
[adr/0006-contract-status-and-slice-shape.md](adr/0006-contract-status-and-slice-shape.md)
(koniz-dev/flutter-starter#183) gives each a verdict: **`AppDesignTokens` is to
be wired** - type `AppTheme._tokens` on the abstraction - and
**`IAuthController` is to be removed**, with `AuthStateSnapshot`,
`ControllerStateSnapshot` and `authControllerProvider`. Both rows stay here
describing the tree as it is until those changes land; the ADR says what they
are becoming. Neither is filed yet, and the ADR names the epic and the exact
edit for each.

Two rows that used to sit here were answered by deletion rather than by wiring.
`AppNavigator` went in koniz-dev/flutter-starter#177 - the contract, its adapter
and its provider are gone, and navigation is the `Navigation` row below.
`ITasksController` went in koniz-dev/flutter-starter#180, which removed it and
`TasksStateSnapshot` from `state_boundary_contracts.dart`: it had no implementor
and no consumer, and it had drifted from `TasksNotifier` in both directions - it
declared `loadTasks()` and `clearError()` the notifier never had, and lacked the
`updateTask` the notifier does have. Neither has a row below, which is the
point: a contract that only this file mentions is the defect, not the
documentation of one.

| Status | Means |
| --- | --- |
| **Live** | Production code in `lib/` is typed on the contract and runs against it. Swapping the implementation changes behavior. |
| **No production consumer** | An implementation exists, and for some rows a provider binds it to the contract, but nothing in `lib/` reads that binding. Tests may. Swapping the implementation changes nothing until a consumer exists. |
| **No implementor** | The contract is declared and nothing anywhere implements it. **No contract is in this state today** - `ITasksController` was the last one and was deleted by koniz-dev/flutter-starter#180. The row stays so the state has a name if it recurs. |

| Contract / surface | Status | Default implementation | Wired in / consumed by | To replace |
| --- | --- | --- | --- | --- |
| `INetworkClient` | **Live** | `DioNetworkClient` (`lib/core/network/adapters/dio_network_client.dart:5`) | Field typed on the contract in `ApiClient` (`lib/core/network/api_client.dart:138`), bound to `DioNetworkClient` at `:54`; every `ApiClient` verb method routes through `_send` (`:259`), which calls `_networkClient.send` at `:263`. The public `networkClient` getter (`:154`) has no readers. | No provider binds it: edit `ApiClient`, or supply your own `AuthRemoteDataSource` |
| `ApiClient` (concrete class, not a contract) | **Live** | Dio + interceptors | `apiClientProvider` (`lib/core/di/providers.dart:193`); `networkClientProvider` (`:50`) is a typed alias of the same instance, read at `lib/features/auth/di/auth_providers.dart:43` | Override `apiClientProvider`, or replace feature datasources if you drop Dio |
| `IHttpResponseCache` | **Live** | `CacheInterceptor` (`lib/core/network/interceptors/cache_interceptor.dart:97`) | Exposed as `ApiClient.responseCache` (`lib/core/network/api_client.dart:160`); held by `AuthInterceptor` (`lib/core/network/interceptors/auth_interceptor.dart:118`) and by `AuthRepositoryImpl` (`lib/features/auth/data/repositories/auth_repository_impl.dart:34`), wired at `lib/features/auth/di/auth_providers.dart:65` | Implement the contract and pass it where `CacheInterceptor` is constructed |
| `IKeyValueStore` | **Live** | `StorageService` (`lib/core/storage/storage_service.dart:47`) | `keyValueStoreProvider` (`lib/core/di/providers.dart:38`), read at `lib/features/auth/di/auth_providers.dart:30`, `lib/features/tasks/di/tasks_providers.dart:19`, `lib/features/feature_flags/presentation/providers/feature_flags_providers.dart:18`; fields typed on the contract at `lib/features/auth/data/datasources/auth_local_datasource.dart:54`, `lib/features/tasks/data/datasources/tasks_local_datasource.dart:45`, `lib/features/feature_flags/data/datasources/feature_flags_local_datasource.dart:30` | Provider override to your store |
| `ITokenStore` | **Live** | `SecureTokenStore` (`lib/core/storage/adapters/secure_token_store.dart:6`) | `tokenStoreProvider` (`lib/core/di/providers.dart:43`), read at `lib/features/auth/di/auth_providers.dart:31` and `lib/core/di/providers.dart:172`; fields typed on the contract at `lib/core/network/interceptors/auth_interceptor.dart:52` and `lib/features/auth/data/datasources/auth_local_datasource.dart:57` | Provider override |
| `ISessionTerminationSink` | **Live** | `RiverpodSessionTerminationSink` (`lib/features/auth/presentation/providers/auth_provider.dart:277`) | Bound to `sessionTerminationSinkProvider` by `authModuleOverrides` (`lib/features/auth/di/auth_providers.dart:99`) and read into `AuthInterceptor` at `lib/core/di/providers.dart:179`; held at `lib/core/network/interceptors/auth_interceptor.dart:87` and invoked on forced logout at `:534` | Implement the contract and pass it in the same place |
| Navigation (extension, not a contract) | **Live** | `NavigationExtensions` on `BuildContext` (`lib/core/routing/navigation_extensions.dart:25`) over `go_router` | Every screen that navigates: `lib/features/auth/presentation/screens/login_screen.dart:115`, `register_screen.dart:139`, `lib/features/tasks/presentation/screens/tasks_list_screen.dart:253` and `:283`, `task_detail_screen.dart:118` and `:160`. The router itself is `goRouterProvider` (`lib/core/routing/app_router.dart:15`). | Rewrite `navigation_extensions.dart` and the `lib/features/*/routing/*_routes.dart` modules against your router. There is no navigation contract to implement - see [adr/0003-navigation-boundary.md](adr/0003-navigation-boundary.md) |
| `AppDesignTokens` | **No production consumer** | `DefaultDesignTokens` (`lib/shared/design_system/tokens/default_design_tokens.dart:9`) | Nowhere, and there is no provider. `AppTheme` binds the **concrete** class at compile time: `static const _tokens = DefaultDesignTokens();` (`lib/shared/theme/app_theme.dart:7`). Nothing in `lib/` is typed on `AppDesignTokens`. | Edit `lib/shared/theme/app_theme.dart` to construct your own token class (and update the theme building that reads `_tokens`). There is no override point. |
| `IAuthController` | **No production consumer** | `AuthNotifier` (`lib/features/auth/presentation/providers/auth_provider.dart:47`) | `authControllerProvider` (`lib/features/auth/presentation/providers/auth_provider.dart:284`) binds it, but that identifier has **zero readers** in `lib/` and `test/` - the UI reads the generated `authProvider` directly. | Rebinding `authControllerProvider` to your orchestrator has no effect until something reads it |

Until koniz-dev/flutter-starter#182 there was an `ITasksController` row naming a
controller provider that has never existed anywhere in the tree - the name is
deliberately not repeated here, so that grepping for it stays a clean test.
koniz-dev/flutter-starter#180 then deleted the contract itself.

That is no longer left to a reviewer. Every provider identifier named in the
tables above and below carries a `<!-- symbol: <path> <name> -->` directive,
checked by `tool/doc_symbols.dart` from both `dart run tool/check_docs.dart`
(Docs check, which fires when this file changes) and `test/docs/doc_symbols_test.dart`
(Quality gate, which fires when `lib/` changes). The directives are HTML
comments, so they are invisible in the rendered page; they live here rather
than inline in the cells so the tables stay readable. **If you add or edit a
row, add a directive for every identifier you put in it** - a symbol whose only
occurrence in the repository is this file is the tell, and the directive is what
turns that from a convention into a gate.

<!-- symbol: lib/core/di/providers.dart apiClientProvider -->
<!-- symbol: lib/core/di/providers.dart networkClientProvider -->
<!-- symbol: lib/core/di/providers.dart keyValueStoreProvider -->
<!-- symbol: lib/core/di/providers.dart tokenStoreProvider -->
<!-- symbol: lib/core/logging/logging_providers.dart loggingServiceProvider -->
<!-- symbol: lib/core/routing/app_router.g.dart goRouterProvider -->
<!-- symbol: lib/features/auth/presentation/providers/auth_provider.dart authControllerProvider -->
<!-- symbol: lib/features/auth/presentation/providers/auth_provider.g.dart authProvider -->
<!-- symbol: lib/core/security/rasp_providers.dart raspServiceProvider -->
<!-- symbol: lib/features/feature_flags/presentation/providers/feature_flags_providers.g.dart featureFlagsRemoteDataSourceProvider -->

Two of those paths end in `.g.dart` on purpose. `goRouterProvider`,
`authProvider` and `featureFlagsRemoteDataSourceProvider` are generated from
`@riverpod` annotations and exist nowhere else, so a checker that skipped
generated output would skip exactly the identifiers an adopter is most likely
to mistype.

## Adapter directories (convention)

| Kind | Directory |
| --- | --- |
| Network | `lib/core/network/adapters/` |
| Storage | `lib/core/storage/adapters/` |
| Routing | None. Navigation is a `BuildContext` extension, not a contract plus adapter; `go_router` stays inside `lib/core/routing/` |
| Theme | Prefer tokens in `lib/shared/design_system/` + `lib/shared/theme/app_theme.dart` |
| State | Notifiers under `lib/features/*/presentation/providers/`; one implements a controller contract (`AuthNotifier`), the tasks slice deliberately does not - see koniz-dev/flutter-starter#180 |

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
- `lib/core/**` never imports `lib/features/**` (one seam aside: `routes_registry.dart`). Where core needs something a feature owns - refreshing a token on a 401 - it declares the port and the feature supplies the adapter through `authModuleOverrides`, applied in `createAppContainer()`. `test/tooling/import_rules_test.dart` enforces the direction.

## Related

- [Super starter hub](super-starter-hub.md)
- [Choose your stack](choose-your-stack.md)
- [Quality gates and risks](migrations/quality-gates-and-risks.md)
