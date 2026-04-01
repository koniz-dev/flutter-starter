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
