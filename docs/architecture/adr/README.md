# Architecture Decision Records (ADR)

This folder tracks major architectural decisions for decoupling the starter.

## Status Labels
- `Proposed`: Discussed and ready for implementation planning.
- `Accepted`: Approved and used as implementation baseline.
- `Superseded`: Replaced by another ADR.

## ADR Index
- `0001-network-boundary.md` - Transport-agnostic network contract and Dio adapter boundary.
- `0002-storage-boundary.md` - Split storage contracts into key-value and token-specific concerns.
- `0003-navigation-boundary.md` - Introduce `AppNavigator` to isolate presentation from router APIs.
- `0004-theme-token-boundary.md` - Single semantic token source and theme adapter mapping.
- `0005-state-boundary.md` - Controller boundaries to reduce direct Riverpod coupling.

## Compatibility Policy
- Keep existing public APIs operational during migration via compatibility facades.
- Migrate by feature slices and avoid breaking all modules at once.
- Remove compatibility paths only after one internal release cycle with no regressions.
