# ADR 0005: State Boundary Hardening

- Status: **Superseded** by
  [0006-contract-status-and-slice-shape.md](0006-contract-status-and-slice-shape.md)
  (2026-09-26)
- Date: 2026-03-27

> **Read 0006 first.** Both contracts this ADR proposed are gone:
> `ITasksController` was deleted first, and `IAuthController` followed on
> 0006's verdict. This document is kept as the
> reasoning that was tried, not as a description of the tree. The Context below
> is still accurate; the Decision is not what the repository does.

## Context
Riverpod is currently both DI and UI state engine. Feature presentation logic directly depends on Riverpod notifier/provider APIs, increasing migration cost and coupling.

## Decision
Introduce controller contracts for feature orchestration:
- ~~`IAuthController`~~ - **deleted**; see Implementation status below.
- ~~`ITasksController`~~ - **deleted**; see
  Implementation status below.

Use Riverpod notifiers as adapter implementations behind these contracts. UI components should increasingly depend on controller contracts, not state-engine-specific operations.

## Implementation status

This ADR was never accepted: it went from Proposed to Superseded by 0006, and
the decision above describes a direction that was tried, not the shipped tree.
As of the deletion of both contracts:

| Contract | Implemented by | Consumed by |
| --- | --- | --- |
| `IAuthController` | **Removed**, with `AuthStateSnapshot`, `ControllerStateSnapshot` and the provider that bound it. `AuthNotifier` implemented it, but that provider had no reader in `lib/` or `test/`; the UI reads the generated `authProvider` directly. | n/a |
| `ITasksController` | **Removed.** Deleting the contract also removed `TasksStateSnapshot`; `grep -rn "ITasksController" lib` now returns nothing. | n/a |

So neither half of this decision was carried out. `TasksNotifier` had never
implemented `ITasksController`, the two had drifted in both directions, and the
contract was deleted instead of manufacturing an implementor and a consumer
for it. `IAuthController` had an implementor but no consumer, and
[0006](0006-contract-status-and-slice-shape.md) answered whether to wire it up
or delete it: **remove it**, which has been done. Do not read this ADR as a
description of how the sample features are wired today; the current wiring is
in [contracts-map.md](../contracts-map.md).

<!-- symbol: lib/features/auth/presentation/providers/auth_provider.dart AuthNotifier -->

## Consequences
### Positive
- Reduced lock-in to one state engine in presentation logic.
- Clear boundary for unit tests without ProviderContainer orchestration.
- Enables incremental replacement strategy rather than full rewrite.

### Trade-offs
- Additional abstraction layer and adapter boilerplate.
- Transitional complexity while both patterns coexist.

## Compatibility Criteria
- Existing providers remain functional during transition.
- Migration proceeds feature-by-feature with unchanged UI behavior.
