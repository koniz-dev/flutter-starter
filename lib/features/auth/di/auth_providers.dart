import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart'
    show SecureStorageService;
import 'package:flutter_starter/core/storage/storage_service.dart'
    show StorageService;
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/is_authenticated_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';

// ============================================================================
// Auth Data Source Providers
// ============================================================================

/// Provider for [AuthLocalDataSource] instance
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

/// Provider for [AuthRemoteDataSource] instance
///
/// Uses ref.read to break circular dependency with apiClientProvider.
final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>((ref) {
      final apiClient = ref.read<ApiClient>(apiClientProvider);
      return AuthRemoteDataSourceImpl(apiClient);
    });

// ============================================================================
// Auth Repository Provider
// ============================================================================

/// Provider for [AuthRepository] instance
///
/// Coordinates between remote and local data sources.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      final remoteDataSource = ref.read<AuthRemoteDataSource>(
        authRemoteDataSourceProvider,
      );
      final localDataSource = ref.watch(authLocalDataSourceProvider);
      return AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
      );
    });

// ============================================================================
// Auth Interceptor Provider
// ============================================================================

/// Provider for [AuthInterceptor] instance
///
/// Handles authentication token injection and automatic token refresh on
/// 401 errors. Uses ref.read to break circular dependency.
final Provider<AuthInterceptor> authInterceptorProvider =
    Provider<AuthInterceptor>((ref) {
      final secureStorageService = ref.watch(secureStorageServiceProvider);
      final authRepository = ref.read<AuthRepository>(authRepositoryProvider);
      return AuthInterceptor(
        secureStorageService: secureStorageService,
        authRepository: authRepository,
      );
    });

// ============================================================================
// Auth Use Case Providers
// ============================================================================

/// Provider for [LoginUseCase] instance
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return LoginUseCase(repository);
});

/// Provider for [RegisterUseCase] instance
final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return RegisterUseCase(repository);
});

/// Provider for [LogoutUseCase] instance
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return LogoutUseCase(repository);
});

/// Provider for [RefreshTokenUseCase] instance
final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return RefreshTokenUseCase(repository);
});

/// Provider for [GetCurrentUserUseCase] instance
final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return GetCurrentUserUseCase(repository);
});

/// Provider for [IsAuthenticatedUseCase] instance
final isAuthenticatedUseCaseProvider = Provider<IsAuthenticatedUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return IsAuthenticatedUseCase(repository);
});
