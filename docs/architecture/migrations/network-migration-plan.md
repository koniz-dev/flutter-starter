# Network Migration Plan (De-Dio)

## Objective
Remove direct `Dio` type exposure from feature/data layers while preserving runtime behavior.

## Current Coupling
- `ApiClient` returns `Response<dynamic>` and accepts `Options`.
- Error handling paths include `DioException` assumptions.

Reference file: `lib/core/network/api_client.dart`.

## Incremental Plan

### Increment 1: Introduce adapter without consumers change
- Add `DioNetworkClient` implementing `INetworkClient`.
- Keep current `ApiClient` unchanged.
- Add mapper functions:
  - `NetworkRequest -> Dio request`
  - `Dio response -> NetworkResponse`
  - `DioException -> NetworkError`

Rollback: remove new adapter binding; no consumer impact.

### Increment 2: Compatibility facade
- Update `ApiClient` internals to delegate to `INetworkClient` while preserving existing method signatures.
- Keep return types unchanged for this increment to minimize blast radius.

Rollback: revert `ApiClient` delegation commit only.

### Increment 3: First consumer migration slice (Auth remote datasource)
- Move one data source to call `INetworkClient.send`.
- Replace `Response` parsing with `NetworkResponse`.
- Replace transport-specific error assumptions with `NetworkError` mapping.

Rollback: revert migrated datasource only; adapter remains.

### Increment 4: Remaining consumers migration
- Migrate all core/feature data sources from `ApiClient`/Dio types to contracts.
- Keep facade methods for one release cycle but mark as deprecated.

Rollback: partial per-feature reverts; facade still intact.

### Increment 5: Deprecation enforcement
- Remove direct `Dio` imports from feature/data layers.
- Keep Dio only in `core/network/adapters`.

Rollback: re-enable deprecated facade temporarily if needed.

## Test Strategy
- Contract tests for `INetworkClient` with mocked HTTP scenarios:
  - status success/failure
  - timeout
  - network unavailable
  - malformed payload
- Regression tests for auth flow in `test/features/auth/data`.
- Interceptor behavior tests to ensure auth/logging/performance order is unchanged.

## Exit Criteria
- No feature module imports `package:dio/dio.dart`.
- Core behavior for auth/tasks flows matches baseline tests.
- Error codes/messages mapped through `NetworkError` consistently.
