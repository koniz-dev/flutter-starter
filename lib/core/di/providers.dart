import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/api_client.dart';
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
  return ApiClient(storageService: storageService);
});

/// Provider for [StorageService] instance
/// 
/// This provider creates a singleton instance of [StorageService] that can be
/// used throughout the application for local storage operations.
/// 
/// **Note**: The storage service must be initialized before use by calling
/// `StorageService.init()` in the main function.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provider for [IStorageService] interface
/// 
/// This provider provides the storage service as an interface, allowing for
/// easier testing and potential future implementations.
final iStorageServiceProvider = Provider<IStorageService>((ref) {
  return ref.watch(storageServiceProvider);
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
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return AuthLocalDataSourceImpl(storageService);
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
