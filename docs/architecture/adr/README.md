# Architecture Decision Records (ADR)

This folder tracks major architectural decisions for decoupling the starter.

## Status Labels
- `Proposed`: Discussed and ready for implementation planning.
- `Accepted`: Approved and used as implementation baseline.
- `Superseded`: Replaced by another ADR.

## ADR Index
- `0001-network-boundary.md` - Transport-agnostic network contract and Dio adapter boundary.
- `0002-storage-boundary.md` - Split storage contracts into key-value and token-specific concerns.
- `0003-navigation-boundary.md` - `NavigationExtensions` as the one navigation API; `go_router` confined to `lib/core/routing/`.
- `0004-theme-token-boundary.md` - Single semantic token source and theme adapter mapping.
- `0005-state-boundary.md` - **Superseded by 0006.** Controller boundaries to
  reduce direct Riverpod coupling.
- `0006-contract-status-and-slice-shape.md` - A verdict for every boundary
  contract (load-bearing, removed, or scheduled to be one of the two), and
  `auth` as the canonical feature slice shape. Supersedes 0005.

## Compatibility Policy
- Keep existing public APIs operational during migration via compatibility facades.
- Migrate by feature slices and avoid breaking all modules at once.
- Remove compatibility paths only after one internal release cycle with no regressions.
