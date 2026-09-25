# ADR 0005: State Boundary Hardening

- Status: Proposed
- Date: 2026-03-27

## Context
Riverpod is currently both DI and UI state engine. Feature presentation logic directly depends on Riverpod notifier/provider APIs, increasing migration cost and coupling.

## Decision
Introduce controller contracts for feature orchestration:
- `IAuthController`
- `ITasksController`

Use Riverpod notifiers as adapter implementations behind these contracts. UI components should increasingly depend on controller contracts, not state-engine-specific operations.

## Implementation status

This ADR is still **Proposed**, and the decision above describes an intended
direction, not the shipped tree. As of `48ba708`:

| Contract | Implemented by | Consumed by |
| --- | --- | --- |
| `IAuthController` | `AuthNotifier` (`lib/features/auth/presentation/providers/auth_provider.dart:47`), bound to `authControllerProvider` (`:284`) | Nothing. That provider has zero readers in `lib/` and `test/`; the UI reads the generated `authProvider` directly. |
| `ITasksController` | **Nothing.** `TasksNotifier` (`lib/features/tasks/presentation/providers/tasks_provider.dart:55`) does not implement it. | Nothing. |

So the "UI depends on controller contracts" half of this decision has not been
carried out for either contract, and `ITasksController` has no adapter at all.
Whether to wire them up or delete them is an open question - see
koniz-dev/flutter-starter#64 and koniz-dev/flutter-starter#183. Do not read this
ADR as a description of how the sample features are wired today; the current
wiring is in [contracts-map.md](../contracts-map.md).

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
