// The core DI module. It names no feature, by rule and by test: see
// `core_imports_feature` in `test/tooling/import_rules_test.dart`.
//
// Core still needs one thing a feature owns - how to refresh an access token
// on a 401 - so it declares the *port* here ([tokenRefresherProvider],
// [sessionTerminationSinkProvider]) and the auth slice supplies the adapter
// from `authModuleOverrides` at the composition root. That is what replaced
// the import cycle this file used to close with
// `lib/features/auth/di/auth_providers.dart`
// (koniz-dev/flutter-starter#221).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/performance/performance_providers.dart';
import 'package:flutter_starter/core/session/session_providers.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_migration_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';

/// Refreshes the access token behind a 401, returning the new one.
///
/// The signature [AuthInterceptor] already takes, named so the seam below can
/// talk about it.
typedef TokenRefresher = Future<Result<String>> Function();

// ============================================================================
// Backward-compat providers (stable public surface)
// ============================================================================

/// Backward-compat alias: non-sensitive key/value store.
final keyValueStoreProvider = Provider<IKeyValueStore>((ref) {
  return ref.watch(storageServiceProvider);
});

/// Backward-compat alias: token store for auth.
final tokenStoreProvider = Provider<ITokenStore>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return SecureTokenStore(secureStorage);
});

/// Backward-compat alias: same instance as [apiClientProvider], typed for auth
/// remote datasources that depend on the Dio façade (interceptors, SSL, etc.).
final Provider<ApiClient> networkClientProvider = Provider<ApiClient>((ref) {
  return ref.watch(apiClientProvider);
});

// ============================================================================
// Core Infrastructure Providers
// ============================================================================

/// Provider for [StorageService] instance
///
/// This provider creates a singleton instance of [StorageService] that can be
/// used throughout the application for non-sensitive local storage operations
/// (e.g., user preferences, cached data).
///
/// For sensitive data (tokens, passwords), use [secureStorageServiceProvider].
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provider for [SecureStorageService] instance
///
/// This provider creates a singleton instance of [SecureStorageService] that
/// uses encrypted storage for sensitive data such as authentication tokens.
///
/// Platform-specific:
/// - Android: EncryptedSharedPreferences
/// - iOS: Keychain
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for [IStorageService] interface
///
/// This provider provides the storage service as an interface, allowing for
/// easier testing and potential future implementations.
///
/// **Note**: This defaults to [StorageService] for backward compatibility.
/// For secure storage, use [secureStorageServiceProvider] directly.
final iStorageServiceProvider = Provider<IStorageService>((ref) {
  return ref.watch(storageServiceProvider);
});

/// Startup initialization provider
///
/// This provider initializes storage services and runs migrations before
/// the app starts. It should be awaited in the main function to ensure
/// storage is ready and migrated.
final storageInitializationProvider = FutureProvider<void>((ref) async {
  final storageService = ref.read(storageServiceProvider);
  final secureStorageService = ref.read(secureStorageServiceProvider);
  final loggingService = ref.read(loggingServiceProvider);

  // Initialize storage services
  await storageService.init();

  // Run migrations
  final migrationService = StorageMigrationService(
    storageService: storageService,
    secureStorageService: secureStorageService,
    loggingService: loggingService,
  );
  await migrationService.migrateAll();
});

// ============================================================================
// Network Provider
// ============================================================================

// ============================================================================
// Authentication seams
// ============================================================================
//
// [apiClientProvider] needs an [AuthInterceptor], and refreshing a token is
// the authentication feature's job. Core therefore declares what it needs as
// two overridable ports and never learns which feature fills them. The auth
// slice exports `authModuleOverrides`, which `createAppContainer()` in
// `lib/main.dart` applies; a container built without them still resolves
// every provider here, it simply cannot refresh a session.

/// How the 401 flow mints a new access token.
///
/// Defaults to a failure naming the missing override rather than throwing: it
/// is called from the interceptor's error path, where an uncaught throw would
/// replace a recoverable 401 with an unhandled async error. The failure code
/// is `NO_TOKEN_REFRESHER` and the outcome is a forced logout, which is the
/// safe direction for an app whose session cannot be renewed.
///
/// Read inside the callback rather than captured, so an override applied to
/// the container is honoured no matter when the interceptor was built.
final Provider<TokenRefresher> tokenRefresherProvider =
    Provider<TokenRefresher>((ref) {
      return () async => const ResultFailure(
        UnknownFailure(
          'No token refresher is registered. Add authModuleOverrides from '
          'lib/features/auth/di/auth_providers.dart to your ProviderScope.',
          code: 'NO_TOKEN_REFRESHER',
        ),
      );
    });

/// Where a forced logout reports that the session is gone.
///
/// Null by default, which is exactly the degraded behaviour
/// [AuthInterceptor] already documents for a missing sink: storage is torn
/// down, the in-memory session is not. The auth slice overrides it with its
/// Riverpod-backed sink (koniz-dev/flutter-starter#127).
final Provider<ISessionTerminationSink?> sessionTerminationSinkProvider =
    Provider<ISessionTerminationSink?>((ref) => null);

/// Provider for [AuthInterceptor] instance
///
/// Handles authentication token injection and automatic token refresh on
/// 401 errors.
///
/// Lives in core, beside the [apiClientProvider] that installs it, because
/// every dependency it has is core-owned once the two seams above stand in
/// for the feature. It used to live in `lib/features/auth/di/` and was the
/// single symbol that closed the core <-> feature import cycle
/// (koniz-dev/flutter-starter#221).
final Provider<AuthInterceptor> authInterceptorProvider =
    Provider<AuthInterceptor>((ref) {
      final interceptor = AuthInterceptor(
        tokenStore: ref.watch(tokenStoreProvider),
        refreshToken: () => ref.read(tokenRefresherProvider)(),
        // A forced logout on a failed refresh has to drop the cached user too,
        // or the app keeps presenting a session it has no token for.
        keyValueStore: ref.watch(keyValueStoreProvider),
        // ...and has to drop the *in-memory* session as well, or the running
        // app keeps presenting one until it is restarted (#127).
        sessionSink: ref.read(sessionTerminationSinkProvider),
        // Shared with `authRepositoryProvider`, so a logout raised on either
        // side is visible to a refresh in flight on the other (#169).
        sessionGeneration: ref.watch(sessionGenerationProvider),
      );
      // Releases the single 401-replay client and its connection pool.
      ref.onDispose(interceptor.dispose);
      return interceptor;
    });

/// Provider for [ApiClient] instance
///
/// This provider creates a singleton instance of [ApiClient] that can be used
/// throughout the application for making HTTP requests.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final secureStorageService = ref.watch(secureStorageServiceProvider);
  // Use ref.read to break circular dependency
  final authInterceptor = ref.read<AuthInterceptor>(authInterceptorProvider);
  final loggingService = ref.read(loggingServiceProvider);
  final performanceService = ref.read(performanceServiceProvider);
  return ApiClient(
    storageService: storageService,
    secureStorageService: secureStorageService,
    authInterceptor: authInterceptor,
    loggingService: loggingService,
    performanceService: performanceService,
  );
});
