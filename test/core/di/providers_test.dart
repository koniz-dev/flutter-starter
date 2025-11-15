import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/is_authenticated_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Storage Providers', () {
      test('storageServiceProvider should provide StorageService', () {
        final service = container.read(storageServiceProvider);
        expect(service, isA<StorageService>());
      });

      test('secureStorageServiceProvider should provide SecureStorageService',
          () {
        final service = container.read(secureStorageServiceProvider);
        expect(service, isA<SecureStorageService>());
      });

      test('iStorageServiceProvider should provide IStorageService', () {
        final service = container.read(iStorageServiceProvider);
        expect(service, isA<IStorageService>());
      });

      test('storageInitializationProvider should initialize storage', () async {
        final future = container.read(storageInitializationProvider.future);
        await future;
        expect(future, completes);
      });
    });

    group('Auth Data Source Providers', () {
      test('authLocalDataSourceProvider should provide AuthLocalDataSource',
          () {
        final dataSource = container.read(authLocalDataSourceProvider);
        expect(dataSource, isA<AuthLocalDataSource>());
      });

      test('authRemoteDataSourceProvider should provide AuthRemoteDataSource',
          () {
        final dataSource = container.read(authRemoteDataSourceProvider);
        expect(dataSource, isA<AuthRemoteDataSource>());
      });
    });

    group('Auth Repository Provider', () {
      test('authRepositoryProvider should provide AuthRepository', () {
        final repository = container.read(authRepositoryProvider);
        expect(repository, isA<AuthRepository>());
      });
    });

    group('Auth Interceptor Provider', () {
      test('authInterceptorProvider should provide AuthInterceptor', () {
        final interceptor = container.read(authInterceptorProvider);
        expect(interceptor, isA<AuthInterceptor>());
      });
    });

    group('API Client Provider', () {
      test('apiClientProvider should provide ApiClient', () {
        final apiClient = container.read(apiClientProvider);
        expect(apiClient, isA<ApiClient>());
      });
    });

    group('Use Case Providers', () {
      test('loginUseCaseProvider should provide LoginUseCase', () {
        final useCase = container.read(loginUseCaseProvider);
        expect(useCase, isA<LoginUseCase>());
      });

      test('registerUseCaseProvider should provide RegisterUseCase', () {
        final useCase = container.read(registerUseCaseProvider);
        expect(useCase, isA<RegisterUseCase>());
      });

      test('logoutUseCaseProvider should provide LogoutUseCase', () {
        final useCase = container.read(logoutUseCaseProvider);
        expect(useCase, isA<LogoutUseCase>());
      });

      test('refreshTokenUseCaseProvider should provide RefreshTokenUseCase',
          () {
        final useCase = container.read(refreshTokenUseCaseProvider);
        expect(useCase, isA<RefreshTokenUseCase>());
      });

      test('getCurrentUserUseCaseProvider should provide GetCurrentUserUseCase',
          () {
        final useCase = container.read(getCurrentUserUseCaseProvider);
        expect(useCase, isA<GetCurrentUserUseCase>());
      });

      test(
        'isAuthenticatedUseCaseProvider should provide IsAuthenticatedUseCase',
        () {
          final useCase = container.read(isAuthenticatedUseCaseProvider);
          expect(useCase, isA<IsAuthenticatedUseCase>());
        },
      );
    });

    group('Provider Dependencies', () {
      test('authLocalDataSourceProvider should depend on storage providers',
          () {
        final dataSource = container.read(authLocalDataSourceProvider);
        expect(dataSource, isNotNull);
      });

      test('authRemoteDataSourceProvider should depend on apiClientProvider',
          () {
        final dataSource = container.read(authRemoteDataSourceProvider);
        expect(dataSource, isNotNull);
      });

      test('authRepositoryProvider should depend on data source providers',
          () {
        final repository = container.read(authRepositoryProvider);
        expect(repository, isNotNull);
      });

      test('use case providers should depend on authRepositoryProvider', () {
        final loginUseCase = container.read(loginUseCaseProvider);
        final registerUseCase = container.read(registerUseCaseProvider);
        expect(loginUseCase, isNotNull);
        expect(registerUseCase, isNotNull);
      });

      test(
        'apiClientProvider should depend on storage and interceptor providers',
        () {
          final apiClient = container.read(apiClientProvider);
          expect(apiClient, isNotNull);
        },
      );

      test(
        'authInterceptorProvider should depend on secure storage '
        'and repository',
        () {
          final interceptor = container.read(authInterceptorProvider);
          expect(interceptor, isNotNull);
        },
      );
    });

    group('Provider Singleton Behavior', () {
      test('storageServiceProvider should return same instance', () {
        final service1 = container.read(storageServiceProvider);
        final service2 = container.read(storageServiceProvider);
        expect(service1, same(service2));
      });

      test('secureStorageServiceProvider should return same instance', () {
        final service1 = container.read(secureStorageServiceProvider);
        final service2 = container.read(secureStorageServiceProvider);
        expect(service1, same(service2));
      });

      test('iStorageServiceProvider should return storageService', () {
        final iService = container.read(iStorageServiceProvider);
        final storageService = container.read(storageServiceProvider);
        expect(iService, same(storageService));
      });
    });
  });
}
