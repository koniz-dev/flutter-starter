import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/is_authenticated_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/create_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/delete_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/toggle_task_completion_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/update_task_usecase.dart';
import 'package:flutter_starter/main.dart' show createStartupContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize Flutter binding for tests that need it
  TestWidgetsFlutterBinding.ensureInitialized();

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

      test(
        'secureStorageServiceProvider should provide SecureStorageService',
        () {
          final service = container.read(secureStorageServiceProvider);
          expect(service, isA<SecureStorageService>());
        },
      );

      test('iStorageServiceProvider should provide IStorageService', () {
        final service = container.read(iStorageServiceProvider);
        expect(service, isA<IStorageService>());
      });
    });

    group('Auth Data Source Providers', () {
      test(
        'authLocalDataSourceProvider should provide AuthLocalDataSource',
        () {
          final dataSource = container.read(authLocalDataSourceProvider);
          expect(dataSource, isA<AuthLocalDataSource>());
        },
      );

      test(
        'authRemoteDataSourceProvider should provide AuthRemoteDataSource',
        () {
          final dataSource = container.read(authRemoteDataSourceProvider);
          expect(dataSource, isA<AuthRemoteDataSource>());
        },
      );
    });

    group('Auth Repository Provider', () {
      test('authRepositoryProvider should provide AuthRepository', () {
        final repo = container.read(authRepositoryProvider);
        expect(repo, isA<AuthRepository>());
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
        final client = container.read(apiClientProvider);
        expect(client, isA<ApiClient>());
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

      test(
        'refreshTokenUseCaseProvider should provide RefreshTokenUseCase',
        () {
          final useCase = container.read(refreshTokenUseCaseProvider);
          expect(useCase, isA<RefreshTokenUseCase>());
        },
      );

      test(
        'getCurrentUserUseCaseProvider should provide GetCurrentUserUseCase',
        () {
          final useCase = container.read(getCurrentUserUseCaseProvider);
          expect(useCase, isA<GetCurrentUserUseCase>());
        },
      );

      test(
        'isAuthenticatedUseCaseProvider should provide IsAuthenticatedUseCase',
        () {
          final useCase = container.read(isAuthenticatedUseCaseProvider);
          expect(useCase, isA<IsAuthenticatedUseCase>());
        },
      );
    });

    group('Provider Dependencies', () {
      test(
        'authLocalDataSourceProvider should depend on storage providers',
        () {
          final dataSource = container.read(authLocalDataSourceProvider);
          expect(dataSource, isNotNull);
        },
      );

      test(
        'authRemoteDataSourceProvider should depend on apiClientProvider',
        () {
          final dataSource = container.read(authRemoteDataSourceProvider);
          expect(dataSource, isNotNull);
        },
      );

      test('authRepositoryProvider should depend on data source providers', () {
        final repo = container.read(authRepositoryProvider);
        expect(repo, isNotNull);
      });

      test('use case providers should depend on authRepositoryProvider', () {
        expect(container.read(loginUseCaseProvider), isNotNull);
        expect(container.read(registerUseCaseProvider), isNotNull);
      });

      test(
        'apiClientProvider should depend on storage and interceptor providers',
        () {
          expect(container.read(apiClientProvider), isNotNull);
        },
      );

      test('authInterceptorProvider should depend on secure storage '
          'and repository', () {
        expect(container.read(authInterceptorProvider), isNotNull);
      });
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

    group('Tasks Providers', () {
      test(
        'tasksLocalDataSourceProvider should provide TasksLocalDataSource',
        () {
          final dataSource = container.read(tasksLocalDataSourceProvider);
          expect(dataSource, isNotNull);
          expect(dataSource, isA<TasksLocalDataSource>());
        },
      );

      test('tasksRepositoryProvider should provide TasksRepository', () {
        final repository = container.read(tasksRepositoryProvider);
        expect(repository, isNotNull);
        expect(repository, isA<TasksRepository>());
      });

      test('getAllTasksUseCaseProvider should provide GetAllTasksUseCase', () {
        final useCase = container.read(getAllTasksUseCaseProvider);
        expect(useCase, isNotNull);
        expect(useCase, isA<GetAllTasksUseCase>());
      });

      test('getTaskByIdUseCaseProvider should provide GetTaskByIdUseCase', () {
        final useCase = container.read(getTaskByIdUseCaseProvider);
        expect(useCase, isNotNull);
        expect(useCase, isA<GetTaskByIdUseCase>());
      });

      test('createTaskUseCaseProvider should provide CreateTaskUseCase', () {
        final useCase = container.read(createTaskUseCaseProvider);
        expect(useCase, isNotNull);
        expect(useCase, isA<CreateTaskUseCase>());
      });

      test('updateTaskUseCaseProvider should provide UpdateTaskUseCase', () {
        final useCase = container.read(updateTaskUseCaseProvider);
        expect(useCase, isNotNull);
        expect(useCase, isA<UpdateTaskUseCase>());
      });

      test('deleteTaskUseCaseProvider should provide DeleteTaskUseCase', () {
        final useCase = container.read(deleteTaskUseCaseProvider);
        expect(useCase, isNotNull);
        expect(useCase, isA<DeleteTaskUseCase>());
      });

      test('toggleTaskCompletionUseCaseProvider should provide '
          'ToggleTaskCompletionUseCase', () {
        final useCase = container.read(toggleTaskCompletionUseCaseProvider);
        expect(useCase, isNotNull);
        expect(useCase, isA<ToggleTaskCompletionUseCase>());
      });
    });

    group('Tasks Provider Dependencies', () {
      test(
        'tasksLocalDataSourceProvider should depend on storageServiceProvider',
        () {
          final dataSource = container.read(tasksLocalDataSourceProvider);
          expect(dataSource, isNotNull);
        },
      );

      test('tasksRepositoryProvider should depend on '
          'tasksLocalDataSourceProvider', () {
        final repository = container.read(tasksRepositoryProvider);
        expect(repository, isNotNull);
      });

      test(
        'tasks use case providers should depend on tasksRepositoryProvider',
        () {
          final getAllUseCase = container.read(getAllTasksUseCaseProvider);
          final getByIdUseCase = container.read(getTaskByIdUseCaseProvider);
          final createUseCase = container.read(createTaskUseCaseProvider);
          final updateUseCase = container.read(updateTaskUseCaseProvider);
          final deleteUseCase = container.read(deleteTaskUseCaseProvider);
          final toggleUseCase = container.read(
            toggleTaskCompletionUseCaseProvider,
          );

          expect(getAllUseCase, isNotNull);
          expect(getByIdUseCase, isNotNull);
          expect(createUseCase, isNotNull);
          expect(updateUseCase, isNotNull);
          expect(deleteUseCase, isNotNull);
          expect(toggleUseCase, isNotNull);
        },
      );
    });

    group('Provider Instance Types', () {
      test('all storage providers should return correct types', () {
        final storageService = container.read(storageServiceProvider);
        final secureStorageService = container.read(
          secureStorageServiceProvider,
        );
        final iStorageService = container.read(iStorageServiceProvider);

        expect(storageService, isA<StorageService>());
        expect(secureStorageService, isA<SecureStorageService>());
        expect(iStorageService, isA<IStorageService>());
      });

      test('authLocalDataSourceProvider should return correct type', () {
        final dataSource = container.read(authLocalDataSourceProvider);
        expect(dataSource, isA<AuthLocalDataSource>());
      });
    });

    // Before #53 this group held three verbatim duplicates of the tests above,
    // every one of which ended in `expect(true, isTrue)` or
    // `expect(e, isNotNull)` inside a `catch`. Replacing the whole body of
    // `storageInitializationProvider` with `async {}` left all of them green.
    //
    // These tests assert what the provider is actually for: both stores end up
    // stamped at the current schema version, and a failure on either leg
    // reaches the caller instead of being swallowed. `main()` awaits this
    // provider before `runApp`, so a silent failure means launching on
    // unmigrated data.
    group('storageInitializationProvider', () {
      final secureBacking = <String, String>{};

      /// Installs an in-memory Keychain for the secure store.
      ///
      /// Without it the plugin channel is unimplemented, every secure write is
      /// swallowed into `false`, and the version stamp never persists.
      void installSecureBackend() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_secureChannel, (methodCall) async {
              final arguments = methodCall.arguments as Map<Object?, Object?>?;
              final key = arguments?['key'] as String? ?? '';
              switch (methodCall.method) {
                case 'read':
                  return secureBacking[key];
                case 'write':
                  secureBacking[key] = arguments?['value'] as String? ?? '';
                  return null;
                case 'delete':
                  secureBacking.remove(key);
                  return null;
                case 'deleteAll':
                  secureBacking.clear();
                  return null;
                default:
                  return null;
              }
            });
      }

      void removeSecureBackend() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_secureChannel, null);
      }

      setUp(() {
        SharedPreferences.setMockInitialValues({});
        secureBacking.clear();
        installSecureBackend();
      });

      tearDown(() {
        secureBacking.clear();
        removeSecureBackend();
      });

      test('stamps both stores at the current schema version', () async {
        await container.read(storageInitializationProvider.future);

        final storageService = container.read(storageServiceProvider);
        expect(
          await storageService.getString(StorageVersion.versionKey),
          StorageVersion.current.toString(),
          reason: 'regular storage must end up migrated, not merely touched',
        );
        expect(
          secureBacking[StorageVersion.versionKey],
          StorageVersion.current.toString(),
          reason: 'the secure store is migrated on the same startup path',
        );
      }, timeout: const Timeout(Duration(seconds: 10)));

      test('surfaces a storage init failure to the caller', () async {
        final failingContainer = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(_FailingStorageService()),
          ],
        );
        addTearDown(failingContainer.dispose);

        await expectLater(
          failingContainer.read(storageInitializationProvider.future),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              _FailingStorageService.failureMessage,
            ),
          ),
        );
      }, timeout: const Timeout(Duration(seconds: 10)));

      test('surfaces a migration failure to the caller', () async {
        // No secure backend: every secure write is swallowed, so the version
        // stamp cannot persist and MigrationExecutor reports it rather than
        // returning a success the next launch would contradict.
        removeSecureBackend();

        // Read through the container `main()` actually builds
        // (koniz-dev/flutter-starter#101). It opts out of Riverpod 3's default
        // retry, which would otherwise keep retrying this failure because
        // `MigrationExecutionException implements Exception` rather than
        // `Error` - and with `read(...future)` awaiting without listening, the
        // retry never rebuilds and this future never completes at all. Using
        // the app's own factory here means a regression in `main.dart` fails
        // this test instead of hiding behind a hand-rolled container.
        final startupContainer = createStartupContainer();
        addTearDown(startupContainer.dispose);

        await expectLater(
          startupContainer.read(storageInitializationProvider.future),
          throwsA(isA<MigrationExecutionException>()),
        );
      }, timeout: const Timeout(Duration(seconds: 10)));
    });
  });
}

const MethodChannel _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// A [StorageService] whose `init()` always fails, standing in for a storage
/// backend that is unavailable at startup.
class _FailingStorageService extends StorageService {
  static const String failureMessage = 'storage backend unavailable';

  @override
  Future<void> init() async => throw StateError(failureMessage);
}
