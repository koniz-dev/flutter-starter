import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is not in flutter_riverpod.dart's export list; misc.dart is where
// riverpod 3 keeps it. Same import main.dart uses.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/session/session_providers.dart';
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
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';

// ============================================================================
// Auth Data Source Providers
// ============================================================================

/// Provider for [AuthLocalDataSource] instance
///
/// Uses:
/// - [ITokenStore] for tokens (secure)
/// - [IKeyValueStore] for user data (non-sensitive)
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final storageService = ref.watch(keyValueStoreProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  return AuthLocalDataSourceImpl(
    storageService: storageService,
    tokenStore: tokenStore,
  );
});

/// Provider for [AuthRemoteDataSource] instance
///
/// Uses ref.read to break circular dependency with apiClientProvider.
final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>((ref) {
      final apiClient = ref.read(networkClientProvider);
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
        // Same ApiClient instance the remote data source already resolved, so
        // this adds no new edge to the provider graph.
        httpCache: ref.read(networkClientProvider).responseCache,
        // The *same* instance `authInterceptorProvider` holds. Two of the
        // three credential writes behind one 401 refresh happen in this
        // repository and one in the interceptor; they only agree about which
        // session is live if they share this counter (#169).
        sessionGeneration: ref.watch(sessionGenerationProvider),
      );
    });

// ============================================================================
// Core seam adapters
// ============================================================================

/// Plugs this slice into the authentication seams `lib/core/di/providers.dart`
/// declares, and is the only wiring the app needs to add for the 401 refresh
/// flow to work.
///
/// Core declares [tokenRefresherProvider] and [sessionTerminationSinkProvider]
/// with degraded defaults because `apiClientProvider` must be resolvable
/// without naming a feature; this list is where the real implementations
/// arrive. `createAppContainer()` in `lib/main.dart` applies it, and any test
/// that drives a real 401 through `apiClientProvider` must too.
///
/// This replaced `authInterceptorProvider` living here, which was the single
/// symbol closing the `lib/core/di/` <-> `lib/features/auth/di/` import cycle
/// (koniz-dev/flutter-starter#221). Dependency direction now runs one way:
/// feature -> core.
final List<Override> authModuleOverrides = <Override>[
  tokenRefresherProvider.overrideWith(
    (ref) =>
        () => ref.read(authRepositoryProvider).refreshToken(),
  ),
  // The feature implements the contract and hands it down; `lib/core/network`
  // never learns that a Riverpod notifier is what it just cleared (#127).
  sessionTerminationSinkProvider.overrideWith(
    RiverpodSessionTerminationSink.new,
  ),
];

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
