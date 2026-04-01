# ADR 0001: Network Boundary (De-Dio)

- Status: Proposed
- Date: 2026-03-27

## Context
Current networking is centered around `ApiClient` and exposes `Dio` types (`Response`, `Options`, `DioException`) across multiple layers. This makes transport replacement expensive and propagates vendor details outside adapter boundaries.

## Decision
Adopt a transport-agnostic network contract in core:
- `INetworkClient`
- `NetworkRequest`
- `NetworkResponse`
- `NetworkMethod`
- `NetworkError`

Keep `Dio` inside a dedicated adapter implementation (`DioNetworkClient`). Retain the current `ApiClient` as a compatibility facade during migration.

## Consequences
### Positive
- Repositories/data sources can depend on framework-agnostic contracts.
- Enables incremental migration to other HTTP stacks without broad rewrites.
- Error semantics become explicit and testable without vendor mocks.

### Trade-offs
- Temporary duplication (`ApiClient` + `INetworkClient`) during migration.
- Requires adapter-level mapping for headers, query params, and exceptions.

## Compatibility Criteria
- Existing features continue to work through compatibility facade.
- New code should depend on `INetworkClient` contract first.
- Remove direct Dio surface only after all critical features migrate.
