# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0+1] - Enterprise Starter V2.0 Upgrade

### Added
- **Security**: Implemented FreeRASP (Runtime Application Self-Protection) with threat detection for root/jailbreak, emulator, debugger, unofficial store, and tampering.
- **Security**: Added SSL/Certificate Pinning via custom Dio `IOHttpClientAdapter` and `sha256` fingerprints validation.
- **Networking**: Added `RetryInterceptor` with exponential backoff algorithm to automatically retry requests encountering transient failures (timeout, 5xx).
- **Architecture**: Enforced strict Clean Architecture boundaries with `core/contracts` and transport-agnostic `INetworkClient`.
- **Infrastructure**: Added `StorageMigrationService` to handle safe schema versioning across releases.
- **Testing**: Reached industry-leading coverage ratio (2.25:1) with over 2,216 passing tests.

### Changed
- **CI/CD**: Upgraded GitHub Actions pipelines to modern runner syntax (v4/v5 versions) to prevent deprecation issues. Added native `cache: true` optimization for `subosito/flutter-action`.
- **Performance**: Decoupled Firebase dependencies (`firebase_core`, `firebase_performance`, `firebase_remote_config`) into optional `.template` files, saving ~5-8MB base bundle size for users who do not require Firebase.
- **API Client**: Consolidated logging logic into a unified `ApiLoggingInterceptor`.
- **Error Handling**: Enhanced `result.dart` and `failures.dart` to support a cohesive `copyWith` pattern across typed domain failures.

### Removed
- **Redundant Code**: Excluded unneeded Firebase logic out of the standard compiler path to enforce a lightweight starter philosophy.
- **Obsolete Utilities**: Removed `logging_interceptor.dart` in favor of full `ApiLoggingInterceptor` integration.
