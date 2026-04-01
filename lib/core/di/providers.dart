import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/performance/performance_providers.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_migration_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';

// Re-export feature providers for backward compatibility
export 'package:flutter_starter/features/auth/di/auth_providers.dart';
export 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
export 'package:flutter_starter/features/tasks/di/tasks_providers.dart';

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
