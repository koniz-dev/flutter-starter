import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';

/// Provider for [ApiClient] instance
///
/// This provider creates a singleton instance of [ApiClient] that can be used
/// throughout the application for making HTTP requests.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final secureStorageService = ref.watch(secureStorageServiceProvider);
  return ApiClient(
    storageService: storageService,
    secureStorageService: secureStorageService,
  );
});

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
/// This provider initializes storage services before the app starts.
/// It should be awaited in the main function to ensure storage is ready.
final storageInitializationProvider = FutureProvider<void>((ref) async {
  final storageService = ref.read(storageServiceProvider);
  await storageService.init();
});

// ============================================================================
// Auth Feature Providers
// ============================================================================

/// Provider for [AuthRemoteDataSource] instance
///
/// This provider creates a singleton instance of [AuthRemoteDataSourceImpl]
/// that handles remote authentication operations.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRemoteDataSourceImpl(apiClient);
});

/// Provider for [AuthLocalDataSource] instance
///
/// This provider creates a singleton instance of [AuthLocalDataSourceImpl]
/// that handles local authentication data caching.
///
/// Uses:
/// - [SecureStorageService] for tokens (secure)
/// - [StorageService] for user data (non-sensitive)
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final secureStorageService = ref.watch(secureStorageServiceProvider);
  return AuthLocalDataSourceImpl(
    storageService: storageService,
    secureStorageService: secureStorageService,
  );
});

/// Provider for [AuthRepository] instance
///
/// This provider creates a singleton instance of [AuthRepositoryImpl]
/// that coordinates between remote and local data sources.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final localDataSource = ref.watch(authLocalDataSourceProvider);
  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

/// Provider for [LoginUseCase] instance
///
/// This provider creates a singleton instance of [LoginUseCase]
/// that handles user login business logic.
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
});
