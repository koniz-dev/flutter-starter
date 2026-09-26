# ADR 0005: State Boundary Hardening

- Status: **Superseded** by
  [0006-contract-status-and-slice-shape.md](0006-contract-status-and-slice-shape.md)
  (2026-09-26)
- Date: 2026-03-27

> **Read 0006 first.** Both contracts this ADR proposed are gone or going:
> `ITasksController` was deleted by koniz-dev/flutter-starter#180, and 0006
> decides to remove `IAuthController` too. This document is kept as the
> reasoning that was tried, not as a description of the tree. The Context below
> is still accurate; the Decision is not what the repository does.

## Context
Riverpod is currently both DI and UI state engine. Feature presentation logic directly depends on Riverpod notifier/provider APIs, increasing migration cost and coupling.

## Decision
Introduce controller contracts for feature orchestration:
- `IAuthController`
- ~~`ITasksController`~~ - **deleted** by koniz-dev/flutter-starter#180; see
  Implementation status below.

Use Riverpod notifiers as adapter implementations behind these contracts. UI components should increasingly depend on controller contracts, not state-engine-specific operations.

## Implementation status

This ADR is still **Proposed**, and the decision above describes an intended
direction, not the shipped tree. As of `0e397bf` plus
koniz-dev/flutter-starter#180:

| Contract | Implemented by | Consumed by |
| --- | --- | --- |
| `IAuthController` | `AuthNotifier` (`lib/features/auth/presentation/providers/auth_provider.dart:47`), bound to `authControllerProvider` (`:284`) | Nothing. That provider has zero readers in `lib/` and `test/`; the UI reads the generated `authProvider` directly. |
| `ITasksController` | **Removed.** koniz-dev/flutter-starter#180 deleted the contract and `TasksStateSnapshot`; `grep -rn "ITasksController" lib` now returns nothing. | n/a |

So the "UI depends on controller contracts" half of this decision has not been
carried out for `IAuthController`, and the tasks half of the decision was
reversed rather than completed: `TasksNotifier` had never implemented
`ITasksController`, the two had drifted in both directions, and
koniz-dev/flutter-starter#180 deleted the contract instead of manufacturing an
implementor and a consumer for it. Whether `IAuthController` should be wired up
or deleted in turn was answered by
[0006](0006-contract-status-and-slice-shape.md) (koniz-dev/flutter-starter#183):
**remove it**, with `AuthStateSnapshot`, `ControllerStateSnapshot` and
`authControllerProvider`. Do not read this ADR as a description of how the
sample features are wired today; the current wiring is in
[contracts-map.md](../contracts-map.md).

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
