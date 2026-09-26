# ADR 0006: Which core contracts are load-bearing, and which feature slice shape is canonical

- Status: Accepted
- Date: 2026-09-26
- Supersedes: [0005-state-boundary.md](0005-state-boundary.md)

## Context

`lib/core/contracts/` has declared boundary contracts since ADRs 0001-0005 were
written, and nothing in this repository ever recorded which of them the running
app actually depends on. koniz-dev/flutter-starter#64 was filed on the claim
that "the contracts layer is largely dead"; that was true on 2026-09-14 and is
not true now. Two contracts that did not exist when #64 was filed -
`IHttpResponseCache` (koniz-dev/flutter-starter#114) and
`ISessionTerminationSink` (koniz-dev/flutter-starter#127) - were added
specifically to hold the dependency rule, and two dead ones have since been
deleted.

The gap this ADR closes is not "some contracts are dead". It is that **no
document assigned a verdict**, so a contract with no consumer looked identical
to one that had simply not been wired yet, and three of them sat that way for
months. [contracts-map.md](../contracts-map.md) describes what the wiring *is*;
this ADR records what each contract's status *should be*, which is a different
question and the one nobody was answering.

Every line and symbol below was re-derived against `main` at `da030fa` with
`grep -rn "<symbol>" lib`.

## Decision 1: a verdict for every boundary contract

**"Declared with no production consumer" is not a status a contract may hold.**
Every contract in `lib/core/contracts/` is either load-bearing - production code
in `lib/` is typed on it and runs against it - or it is removed. A contract in
neither state is a claim the template makes and does not keep, and it is
exactly what koniz-dev/flutter-starter#180 found when `ITasksController` had
drifted from `TasksNotifier` in both directions with nobody noticing.

Nine boundary contracts have existed across the life of #64. Here is each one.

### Load-bearing (5)

| Contract | Named production consumer | Implementation |
|---|---|---|
| `INetworkClient` | `ApiClient._networkClient` (`lib/core/network/api_client.dart:138`), called from `_send` (`:259`), which every verb method routes through | `DioNetworkClient` (`lib/core/network/adapters/dio_network_client.dart:5`) |
| `IKeyValueStore` | `AuthLocalDataSourceImpl` (`lib/features/auth/data/datasources/auth_local_datasource.dart:54`), `TasksLocalDataSourceImpl` (`lib/features/tasks/data/datasources/tasks_local_datasource.dart:45`), `FeatureFlagsLocalDataSourceImpl` (`lib/features/feature_flags/data/datasources/feature_flags_local_datasource.dart:30`), `AuthInterceptor` (`lib/core/network/interceptors/auth_interceptor.dart:67`) | `StorageService` (`lib/core/storage/storage_service.dart:47`) |
| `ITokenStore` | `AuthInterceptor` (`lib/core/network/interceptors/auth_interceptor.dart:52`), `CacheInterceptor` (`lib/core/network/interceptors/cache_interceptor.dart:115`), `AuthLocalDataSourceImpl` (`auth_local_datasource.dart:57`) | `SecureTokenStore` (`lib/core/storage/adapters/secure_token_store.dart:6`) |
| `IHttpResponseCache` | `AuthInterceptor._responseCache` (`auth_interceptor.dart:118`), `AuthRepositoryImpl.httpCache` (`lib/features/auth/data/repositories/auth_repository_impl.dart:35`), exposed as `ApiClient.responseCache` (`api_client.dart:160`) | `CacheInterceptor` (`lib/core/network/interceptors/cache_interceptor.dart:97`) |
| `ISessionTerminationSink` | `AuthInterceptor._sessionSink` (`auth_interceptor.dart:87`), declared as a port at `lib/core/di/providers.dart:156` and filled by `authModuleOverrides` | `RiverpodSessionTerminationSink` (`lib/features/auth/presentation/providers/auth_provider.dart:277`) |

`IKeyValueStore` and `ITokenStore` are listed separately here even though
contracts-map.md pairs them: they have different implementations and different
consumer sets, and a verdict is per contract.

### Removed (2)

| Contract | Removed by | Why |
|---|---|---|
| `AppNavigator` | koniz-dev/flutter-starter#177 | `appNavigatorProvider` was read only by its own test. `NavigationExtensions` is the single navigation API; see [0003-navigation-boundary.md](0003-navigation-boundary.md). The contract, its `GoRouterNavigatorAdapter` and the provider are all gone - `grep -rn "AppNavigator" lib` returns nothing |
| `ITasksController` | koniz-dev/flutter-starter#180 | No implementor and no consumer, and it had drifted from `TasksNotifier` in both directions - it declared `loadTasks()` and `clearError()` the notifier never had, and lacked the `updateTask` it does have. Deleted with `TasksStateSnapshot` rather than manufacturing an implementor |

### Verdict: remove (1)

**`IAuthController` is to be removed**, with `AuthStateSnapshot`,
`ControllerStateSnapshot`, `authControllerProvider`
(`lib/features/auth/presentation/providers/auth_provider.dart:289`) and the
`implements IAuthController` clause on `AuthNotifier` (`:48`).

`AuthNotifier` does implement it, so this is not the `ITasksController` case
exactly - but `authControllerProvider` has **zero readers** in `lib/` and
`test/`; the UI reads the generated `authProvider` directly. The "UI depends on
controller contracts" direction ADR 0005 proposed has not been carried out in
the six months since 0005 was written, and its tasks half was reversed rather
than completed. One contract with an implementor, no consumer and no schedule is the
same claim-not-kept as one with neither.

The alternative - wire the UI onto `authControllerProvider` - was rejected.
It would mean routing every auth screen through a hand-written `Provider` that
re-exposes the generated notifier, losing `@riverpod` code generation at the
call site to gain an abstraction with one implementor and no second candidate.
The starter would be teaching indirection for its own sake, which is the
failure mode ADR 0003 identified for `AppNavigator` and resolved the same way.

Execution belongs to `epic:feature-auth`, following the precedent of
koniz-dev/flutter-starter#180, which removed `ITasksController` from
`lib/core/contracts/state_boundary_contracts.dart` under `epic:feature-tasks`
rather than splitting a four-line deletion across two epics. It is **not filed
yet** - see "Follow-up work" below.

### Verdict: wire it (1)

**`AppDesignTokens` is to become load-bearing**, by typing `AppTheme`'s token
field on the abstraction instead of the concrete class:

```dart
// lib/shared/theme/app_theme.dart:7
static const _tokens = DefaultDesignTokens();        // today
static const AppDesignTokens _tokens = DefaultDesignTokens();   // decided
```

Nothing in `lib/` is currently typed on `AppDesignTokens`: `grep -rn
"AppDesignTokens" lib` returns the declaration
(`lib/core/contracts/design_tokens_contracts.dart:7`) and
`DefaultDesignTokens implements AppDesignTokens`
(`lib/shared/design_system/tokens/default_design_tokens.dart:9`), and nothing
else. So the swap [0004-theme-token-boundary.md](0004-theme-token-boundary.md)
promises requires editing `app_theme.dart`, not overriding anything.

This one is wired rather than removed because the cost is a type annotation and
the contract is the stated decision of ADR 0004, which is Proposed but not
contradicted by anything. Removing it would mean reversing ADR 0004 to save a
7-line file. The removal verdict applied to `IAuthController` does not transfer:
there the wiring cost was a rewrite of every auth screen's provider access.

Execution belongs to `epic:design-system`
(`./scripts/bootstrap-issue-labels.sh --list-map` maps `lib/shared` to it). It
is **not filed yet**.

## Decision 2: `auth` is the canonical feature slice shape

The three slices have three shapes. Measured on `main` at `da030fa`:

| Axis | auth | tasks | feature_flags |
|---|---|---|---|
| `di/` | yes (`di/auth_providers.dart`) | yes (`di/tasks_providers.dart`) | **no** |
| `domain/usecases/` | 6 | 6 | **0** |
| `data/models/` | yes | yes | **no** |
| `routing/` | yes (`auth_routes.dart`) | yes (`tasks_routes.dart`) | yes (`feature_flags_routes.dart`) |
| Wiring lives in | `di/` | `di/` | **`presentation/providers/`** |
| Directories no other slice has | `presentation/widgets/` | - | `data/services/`, `presentation/examples/` |

The `routing/` row corrects koniz-dev/flutter-starter#183's table, which
recorded tasks as having no `routing/`. It has one; all three slices do.

**`auth` is canonical.** It is the only slice that has every axis, it is the
shape `bricks/feature_clean` already generates (minus `routing/`, noted below),
and it is the slice an adopter reads first because it is the one with a real
network boundary. Per axis:

| Axis | Rule | tasks | feature_flags |
|---|---|---|---|
| `di/` | A slice's wiring lives in `di/<slice>_providers.dart`. | conforms | **must conform.** `feature_flags_providers.dart:7-9` produces the only `presentation/` -> `data/` import edges in `lib/`; moving the file to `di/` removes them without changing a line of logic |
| `domain/usecases/` | A slice exposes its operations as use cases, not as repository calls from a notifier. | conforms (6) | **legitimately differs.** Feature flags has no orchestration to put in a use case: every operation is a single repository read or write, and `FeatureFlagsManager` already sits in `lib/core/feature_flags/` as the policy layer. A use case per flag read would be a pass-through |
| `data/models/` | A slice that crosses a serialization boundary has models distinct from its entities. | conforms | **legitimately differs.** `FeatureFlag` is persisted as-is through `IKeyValueStore` with no wire format to map, so a model would duplicate the entity |
| `routing/` | A slice that owns screens declares them in `routing/<slice>_routes.dart`. | conforms | conforms |
| Wiring location | Same as `di/`. | conforms | **must conform** |

`presentation/examples/` and `data/services/` are feature_flags-only and are
**not** part of the canonical shape; nothing in this ADR requires deleting them,
but no new slice should grow them.

`bricks/feature_clean` generates `data/{datasources,models,repositories}`,
`di/`, `domain/{entities,repositories,usecases}` and
`presentation/{providers,screens}` - the auth shape without `routing/`. Adding
`routing/` to the brick is an `epic:tooling-ci` change and is **not filed yet**.

## Decision 3: two outcomes this ADR records rather than decides

Both were decided by sibling children of koniz-dev/flutter-starter#64. They are
here because an ADR that omits them leaves a reader guessing.

**`ApiClient`'s Dio surface** - koniz-dev/flutter-starter#176. The
`Response`-returning overloads are **removed**: every verb on `ApiClient` now
returns `NetworkResponse<dynamic>` (`api_client.dart:169`, `:192`, `:217`,
`:242`) and `_sendWithCompatibility`, which rebuilt a Dio `Response` out of a
`NetworkResponse`, is gone. `Dio get dio` (`:151`) is **kept, undeprecated**, as
a documented escape hatch that is deliberately not on any request path - for
swapping `Dio.httpClientAdapter`, inspecting `Dio.interceptors` or reading
`BaseOptions`. Typing a data source on what it returns puts `package:dio` back
in the feature layer, which is the leak #176 closed;
`test/tooling/import_rules_test.dart` now guards that.

**`AppNavigator`** - koniz-dev/flutter-starter#177. Deleted, with
`GoRouterNavigatorAdapter` and `appNavigatorProvider`. `NavigationExtensions` on
`BuildContext` is the one navigation API, and `go_router` stays inside
`lib/core/routing/`. [0003-navigation-boundary.md](0003-navigation-boundary.md)
is Accepted and carries the full argument.

## Relationship to ADR 0005

This ADR **supersedes** [0005-state-boundary.md](0005-state-boundary.md).

0005 proposed controller contracts for feature orchestration and named two,
`IAuthController` and `ITasksController`. One has been deleted
(koniz-dev/flutter-starter#180) and this ADR decides to delete the other. When
an ADR's entire decision has been reversed, amending it in place produces a
document whose Decision section argues for something the repository has chosen
not to do - which is how 0005 came to carry an "Implementation status" section
contradicting its own Decision. Superseding is the honest record: 0005 stays
readable as the reasoning that was tried, and this ADR is what holds.

What is *kept* from 0005: its Context is still accurate - Riverpod is both DI
and UI state engine here. The conclusion this ADR draws from that is different.
Reducing state-engine lock-in in a **starter** is not worth an abstraction with
one implementor and no consumer; an adopter who needs it can add the contract
against their own second implementation, which is when the abstraction starts
paying for itself. The seam that did earn its keep went the other way:
`ISessionTerminationSink` and `tokenRefresherProvider`
(koniz-dev/flutter-starter#221) exist because `lib/core/` genuinely may not
import `lib/features/`, and they have real consumers on both sides.

## Consequences

### Positive

- Every contract has a verdict, so "declared but unconsumed" becomes a
  detectable defect rather than an indefinite state.
- A reviewer has a baseline for slice shape, and `mason make feature_clean`
  generates the shape the ADR names.
- contracts-map.md and this ADR agree, and say different things: one is the
  wiring as it is, the other is the status as it should be.

### Trade-offs

- Two verdicts (`IAuthController` remove, `AppDesignTokens` wire) are decisions
  without execution. That is the ADR's proper output - it may not touch `lib/` -
  but the gap has to be closed by the follow-ups below, or this ADR becomes the
  next thing that records a decision nobody acts on.
- Declaring `auth` canonical makes `feature_flags` non-conforming on two axes.
  The ADR names which two and why the other two differences are legitimate, so
  the non-conformance is bounded rather than an open-ended cleanup.

## Follow-up work this ADR creates

None of these are filed. They are listed here with epic and exact change so
that filing them is mechanical.

| What | Epic | Change |
|---|---|---|
| Remove `IAuthController` | `epic:feature-auth` | Delete `IAuthController`, `AuthStateSnapshot` and `ControllerStateSnapshot` from `lib/core/contracts/state_boundary_contracts.dart`; delete `authControllerProvider` (`auth_provider.dart:289`) and the `implements IAuthController` clause (`:48`); drop the row and the `<!-- symbol: ... authControllerProvider -->` directive from contracts-map.md |
| Wire `AppDesignTokens` | `epic:design-system` | Type `AppTheme._tokens` on `AppDesignTokens` (`lib/shared/theme/app_theme.dart:7`); update the contracts-map.md row from "No production consumer" to "Live" |
| Teach the brick `routing/` | `epic:tooling-ci` | Add `routing/{{feature_name}}_routes.dart` to `bricks/feature_clean/__brick__`, matching the auth slice |

## Compatibility

Removing `IAuthController` is source-breaking for an adopter who typed against
it. Nothing in this repository does, and the escape hatch is the same one
`ITasksController`'s removal left: declare the contract in your own code against
your own implementations, where it has a second candidate to abstract over.
