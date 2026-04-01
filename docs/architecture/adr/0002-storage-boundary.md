# ADR 0002: Storage Boundary Split

- Status: Proposed
- Date: 2026-03-27

## Context
Storage concerns are mixed between generic key-value usage and token/session management. Critical paths often consume concrete implementations directly, limiting replaceability and test precision.

## Decision
Split storage contracts into distinct responsibilities:
- `IKeyValueStore` for non-sensitive settings and cached app values.
- `ITokenStore` for auth tokens and session secrets.

Map existing implementations (`StorageService`, `SecureStorageService`) via adapters to these contracts.

## Consequences
### Positive
- Clear ownership of sensitive vs non-sensitive data paths.
- Auth/network code no longer needs concrete storage classes.
- Better testability for token rotation and invalidation behavior.

### Trade-offs
- Migration requires touchpoints in auth repository and auth interceptor.
- Temporary adapter wiring overhead in DI.

## Compatibility Criteria
- Keep existing storage providers active during transition.
- `StorageMigrationService` supports both legacy and new contracts for one internal release cycle.
