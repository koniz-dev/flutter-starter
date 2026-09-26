import 'package:flutter/services.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [IKeyValueStore] whose [remove] can be made to throw, so the teardown
/// step that follows it can be observed to run anyway.
///
/// Deliberately a real in-memory store rather than a mock: the assertions are
/// about what is left on the device, not about which methods were called.
class _FailableKeyValueStore implements IKeyValueStore {
  _FailableKeyValueStore({this.removeThrows});

  /// Thrown by [remove] when non-null. Stands in for a
  /// `MissingPluginException` on a stripped build or a `PlatformException`
  /// from a corrupt prefs file.
  final Object? removeThrows;

  final Map<String, Object?> values = <String, Object?>{};

  int removeCalls = 0;

  @override
  Future<bool> remove(String key) async {
    removeCalls++;
    final thrown = removeThrows;
    if (thrown != null) {
      // Typed `Object` on purpose: `clearCache()` has to survive an `Error`
      // as well as an `Exception`, which is what the old `on Exception`
      // clause did not, so the lint's premise does not hold here.
      // ignore: only_throw_errors
      throw thrown;
    }
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    values[key] = value;
    return true;
  }

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      values[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    values[key] = value;
    return true;
  }
}

/// A real in-memory token store, so "the tokens are gone" is asserted by
/// reading them back rather than by a `verify()`.
class _InMemoryTokenStore implements ITokenStore {
  String? accessToken;
  String? refreshToken;

  int clearAllCalls = 0;

  @override
  Future<void> clearAccessToken() async => accessToken = null;

  @override
  Future<void> clearAllTokens() async {
    clearAllCalls++;
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<void> clearRefreshToken() async => refreshToken = null;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> setAccessToken(String token) async {
    accessToken = token;
    return true;
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }
}

/// A token store whose [clearAllTokens] always throws.
class _FailingTokenStore extends _InMemoryTokenStore {
  _FailingTokenStore(this.thrown);

  final Object thrown;

  @override
  Future<void> clearAllTokens() async {
    clearAllCalls++;
    // Same reason as `_FailableKeyValueStore.remove`.
    // ignore: only_throw_errors
    throw thrown;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthLocalDataSourceImpl', () {
    late StorageService storageService;
    late SecureStorageService secureStorageService;
    late AuthLocalDataSourceImpl dataSource;
    final secureStorage = <String, String>{};

    setUp(() async {
      secureStorage.clear();

      // Setup method channel for FlutterSecureStorage
      const secureStorageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
            final arguments = methodCall.arguments as Map<Object?, Object?>?;
            switch (methodCall.method) {
              case 'read':
                final key = arguments?['key'] as String? ?? '';
                return secureStorage[key];
              case 'write':
                final key = arguments?['key'] as String? ?? '';
                final value = arguments?['value'] as String? ?? '';
                secureStorage[key] = value;
                return null;
              case 'delete':
                final key = arguments?['key'] as String? ?? '';
                secureStorage.remove(key);
                return null;
              case 'deleteAll':
                secureStorage.clear();
                return null;
              default:
                return null;
            }
          });

      // Setup method channel for SharedPreferences
      const sharedPrefsChannel = MethodChannel(
        'plugins.flutter.io/shared_preferences',
      );
      final sharedPrefs = <String, dynamic>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedPrefsChannel, (methodCall) async {
            switch (methodCall.method) {
              case 'getAll':
                return sharedPrefs;
              case 'setString':
                final arguments =
                    methodCall.arguments as Map<Object?, Object?>?;
                final key = arguments?['key'] as String? ?? '';
                final value = arguments?['value'] as String? ?? '';
                sharedPrefs[key] = value;
                return true;
              case 'remove':
                final arguments =
                    methodCall.arguments as Map<Object?, Object?>?;
                final key = arguments?['key'] as String? ?? '';
                sharedPrefs.remove(key);
                return true;
              case 'clear':
                sharedPrefs.clear();
                return true;
              default:
                return null;
            }
          });

      storageService = StorageService();
      secureStorageService = SecureStorageService();
      await storageService.init();
      dataSource = AuthLocalDataSourceImpl(
        storageService: storageService,
        tokenStore: SecureTokenStore(secureStorageService),
      );
    });

    tearDown(() async {
      secureStorage.clear();
      await dataSource.clearCache();
      await storageService.clear();
      await secureStorageService.clear();
      const secureStorageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      const sharedPrefsChannel = MethodChannel(
        'plugins.flutter.io/shared_preferences',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedPrefsChannel, null);
    });

    group('Token Storage', () {
      test('should cache token in secure storage', () async {
        const token = 'test_access_token';

        await dataSource.cacheToken(token);

        // Verify token is in secure storage, not regular storage
        final secureToken = await secureStorageService.getString(
          AppConstants.tokenKey,
        );
        final regularToken = await storageService.getString(
          AppConstants.tokenKey,
        );

        expect(secureToken, token);
        expect(regularToken, isNull);
      });

      test('should retrieve token from secure storage', () async {
        const token = 'test_access_token';

        await secureStorageService.setString(AppConstants.tokenKey, token);
        final retrievedToken = await dataSource.getToken();

        expect(retrievedToken, token);
      });

      test('should return null when token does not exist', () async {
        final token = await dataSource.getToken();
        expect(token, isNull);
      });
    });

    group('Refresh Token Storage', () {
      test('should cache refresh token in secure storage', () async {
        const refreshToken = 'test_refresh_token';

        await dataSource.cacheRefreshToken(refreshToken);

        // Verify refresh token is in secure storage, not regular storage
        final secureRefreshToken = await secureStorageService.getString(
          AppConstants.refreshTokenKey,
        );
        final regularRefreshToken = await storageService.getString(
          AppConstants.refreshTokenKey,
        );

        expect(secureRefreshToken, refreshToken);
        expect(regularRefreshToken, isNull);
      });

      test('should retrieve refresh token from secure storage', () async {
        const refreshToken = 'test_refresh_token';

        await secureStorageService.setString(
          AppConstants.refreshTokenKey,
          refreshToken,
        );
        final retrievedRefreshToken = await dataSource.getRefreshToken();

        expect(retrievedRefreshToken, refreshToken);
      });

      test('should return null when refresh token does not exist', () async {
        final refreshToken = await dataSource.getRefreshToken();
        expect(refreshToken, isNull);
      });
    });

    group('User Data Storage', () {
      test('should cache user in regular storage', () async {
        const user = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );

        await dataSource.cacheUser(user);

        // Verify user data is in regular storage, not secure storage
        final regularUserData = await storageService.getString(
          AppConstants.userDataKey,
        );
        final secureUserData = await secureStorageService.getString(
          AppConstants.userDataKey,
        );

        expect(regularUserData, isNotNull);
        expect(secureUserData, isNull);
      });

      test('should retrieve cached user from regular storage', () async {
        const user = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );

        await dataSource.cacheUser(user);
        final retrievedUser = await dataSource.getCachedUser();

        expect(retrievedUser, isNotNull);
        expect(retrievedUser?.id, user.id);
        expect(retrievedUser?.email, user.email);
        expect(retrievedUser?.name, user.name);
      });

      test('should return null when user does not exist', () async {
        final user = await dataSource.getCachedUser();
        expect(user, isNull);
      });
    });

    group('Data Separation', () {
      test('should store tokens in secure storage and user data in regular '
          'storage', () async {
        const token = 'test_token';
        const refreshToken = 'test_refresh_token';
        const user = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );

        await dataSource.cacheToken(token);
        await dataSource.cacheRefreshToken(refreshToken);
        await dataSource.cacheUser(user);

        // Verify tokens are in secure storage
        expect(
          await secureStorageService.getString(AppConstants.tokenKey),
          token,
        );
        expect(
          await secureStorageService.getString(AppConstants.refreshTokenKey),
          refreshToken,
        );

        // Verify tokens are NOT in regular storage
        expect(await storageService.getString(AppConstants.tokenKey), isNull);
        expect(
          await storageService.getString(AppConstants.refreshTokenKey),
          isNull,
        );

        // Verify user data is in regular storage
        expect(
          await storageService.getString(AppConstants.userDataKey),
          isNotNull,
        );

        // Verify user data is NOT in secure storage
        expect(
          await secureStorageService.getString(AppConstants.userDataKey),
          isNull,
        );
      });
    });

    group('Clear Cache', () {
      test('should clear all cached data from both storages', () async {
        const token = 'test_token';
        const refreshToken = 'test_refresh_token';
        const user = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );

        await dataSource.cacheToken(token);
        await dataSource.cacheRefreshToken(refreshToken);
        await dataSource.cacheUser(user);

        await dataSource.clearCache();

        // Verify all data is cleared
        expect(await dataSource.getToken(), isNull);
        expect(await dataSource.getRefreshToken(), isNull);
        expect(await dataSource.getCachedUser(), isNull);
      });
    });

    group('Error Handling', () {
      test('should throw CacheException when token caching fails', () async {
        // Arrange - Mock secure storage to throw exception
        const secureStorageChannel = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
              if (methodCall.method == 'write') {
                throw Exception('Storage write failed');
              }
              return null;
            });

        const token = 'test_token';

        // Act & Assert
        expect(
          () => dataSource.cacheToken(token),
          throwsA(isA<CacheException>()),
        );
      });

      test(
        'should throw CacheException when secure storage write fails',
        () async {
          // Arrange - Mock secure storage to throw exception on write
          const secureStorageChannel = MethodChannel(
            'plugins.it_nomads.com/flutter_secure_storage',
          );
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureStorageChannel, (
                methodCall,
              ) async {
                if (methodCall.method == 'write') {
                  throw PlatformException(
                    code: 'STORAGE_ERROR',
                    message: 'Storage write failed',
                  );
                }
                return null;
              });

          const token = 'test_token';

          // Act & Assert
          expect(
            () => dataSource.cacheToken(token),
            throwsA(isA<CacheException>()),
          );
        },
      );

      test('should throw CacheException when user caching fails', () async {
        // Arrange - Mock storage to throw exception
        const sharedPrefsChannel = MethodChannel(
          'plugins.flutter.io/shared_preferences',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(sharedPrefsChannel, (methodCall) async {
              if (methodCall.method == 'setString') {
                throw PlatformException(
                  code: 'STORAGE_ERROR',
                  message: 'Storage write failed',
                );
              }
              return true;
            });

        final testDataSource = AuthLocalDataSourceImpl(
          storageService: storageService,
          tokenStore: SecureTokenStore(secureStorageService),
        );

        const user = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );

        // Act & Assert
        expect(
          () => testDataSource.cacheUser(user),
          throwsA(isA<CacheException>()),
        );
      });

      test('should throw CacheException when getCachedUser fails', () async {
        // Arrange - Store invalid JSON to trigger decode exception
        await storageService.setString(
          AppConstants.userDataKey,
          'invalid json data',
        );

        // Act & Assert - Should throw CacheException when decoding fails
        await expectLater(
          dataSource.getCachedUser(),
          throwsA(isA<CacheException>()),
        );
      });

      // Note: getToken() and getRefreshToken() cannot throw CacheException
      // because SecureStorageService catches exceptions and returns null

      test(
        'should throw CacheException when cacheRefreshToken fails',
        () async {
          // Arrange - Mock secure storage to throw exception
          const secureStorageChannel = MethodChannel(
            'plugins.it_nomads.com/flutter_secure_storage',
          );
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureStorageChannel, (
                methodCall,
              ) async {
                if (methodCall.method == 'write') {
                  throw Exception('Storage write failed');
                }
                return null;
              });

          const refreshToken = 'test_refresh_token';

          // Act & Assert
          expect(
            () => dataSource.cacheRefreshToken(refreshToken),
            throwsA(isA<CacheException>()),
          );
        },
      );

      test('should throw CacheException when clearCache fails', () async {
        // Arrange - Mock storage to throw exception on remove
        const sharedPrefsChannel = MethodChannel(
          'plugins.flutter.io/shared_preferences',
        );

        // Save original handler from setUp to restore later
        final sharedPrefs = <String, dynamic>{};
        Future<dynamic> originalHandler(MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAll':
              return sharedPrefs;
            case 'setString':
              final arguments = methodCall.arguments as Map<Object?, Object?>?;
              final key = arguments?['key'] as String? ?? '';
              final value = arguments?['value'] as String? ?? '';
              sharedPrefs[key] = value;
              return true;
            case 'remove':
              final arguments = methodCall.arguments as Map<Object?, Object?>?;
              final key = arguments?['key'] as String? ?? '';
              sharedPrefs.remove(key);
              return true;
            case 'clear':
              sharedPrefs.clear();
              return true;
            default:
              return null;
          }
        }

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(sharedPrefsChannel, (methodCall) async {
              if (methodCall.method == 'remove') {
                throw PlatformException(
                  code: 'STORAGE_ERROR',
                  message: 'Storage remove failed',
                );
              }
              // Handle other methods normally
              switch (methodCall.method) {
                case 'getAll':
                  return <String, dynamic>{};
                case 'setString':
                  return true;
                case 'clear':
                  return true;
                default:
                  return null;
              }
            });

        // Create new storage service to avoid cached instance
        final testStorageService = StorageService();
        await testStorageService.init();
        final testDataSource = AuthLocalDataSourceImpl(
          storageService: testStorageService,
          tokenStore: SecureTokenStore(secureStorageService),
        );

        // Restore the handler however the assertion goes, so tearDown does
        // not fail on a still-broken channel.
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(sharedPrefsChannel, originalHandler);
        });

        // Act & Assert
        await expectLater(
          testDataSource.clearCache(),
          throwsA(isA<CacheException>()),
        );
      });
    });

    group('Edge Cases', () {
      test('should handle empty token', () async {
        const emptyToken = '';
        await dataSource.cacheToken(emptyToken);
        final retrieved = await dataSource.getToken();
        expect(retrieved, emptyToken);
      });

      test('should handle empty refresh token', () async {
        const emptyRefreshToken = '';
        await dataSource.cacheRefreshToken(emptyRefreshToken);
        final retrieved = await dataSource.getRefreshToken();
        expect(retrieved, emptyRefreshToken);
      });

      test('should handle very long token', () async {
        final longToken = 'A' * 1000;
        await dataSource.cacheToken(longToken);
        final retrieved = await dataSource.getToken();
        expect(retrieved, longToken);
      });

      test('should handle user with all optional fields', () async {
        const user = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        await dataSource.cacheUser(user);
        final retrieved = await dataSource.getCachedUser();
        expect(retrieved?.avatarUrl, user.avatarUrl);
      });

      test('should handle user with minimal fields', () async {
        const user = UserModel(id: '1', email: 'test@example.com');

        await dataSource.cacheUser(user);
        final retrieved = await dataSource.getCachedUser();
        expect(retrieved?.name, isNull);
        expect(retrieved?.avatarUrl, isNull);
      });

      test('should handle multiple cache operations', () async {
        const token1 = 'token1';
        const token2 = 'token2';

        await dataSource.cacheToken(token1);
        expect(await dataSource.getToken(), token1);

        await dataSource.cacheToken(token2);
        expect(await dataSource.getToken(), token2);
      });

      test('should handle clearCache when no data exists', () async {
        // Should not throw when clearing empty cache
        await dataSource.clearCache();
        expect(await dataSource.getToken(), isNull);
        expect(await dataSource.getRefreshToken(), isNull);
        expect(await dataSource.getCachedUser(), isNull);
      });

      test('should handle getToken when token does not exist', () async {
        final token = await dataSource.getToken();
        expect(token, isNull);
      });

      test(
        'should handle getRefreshToken when refresh token does not exist',
        () async {
          final refreshToken = await dataSource.getRefreshToken();
          expect(refreshToken, isNull);
        },
      );

      test('should handle getCachedUser when user does not exist', () async {
        final user = await dataSource.getCachedUser();
        expect(user, isNull);
      });
    });
  });

  // Regression for koniz-dev/flutter-starter#168 criteria 2 and 3.
  //
  // `clearCache()` used to run both stores' teardown inside one `try`, so a
  // throwing `storageService.remove()` skipped `tokenStore.clearAllTokens()`
  // and left the access token *and* the refresh token in the Keychain /
  // Keystore after an explicit logout. The `on Exception` clause was the other
  // half of it: an `Error` escaped the declared `CacheException` contract raw
  // and skipped the same step.
  //
  // A sibling group rather than a nested one: these drive real in-memory
  // stores directly, so they need none of the method-channel harness above.
  //
  // Counterfactual, actually run
  // (docs/verification/issue-168/counterfactual.log).
  group('clearCache tears its two stores down independently (#168)', () {
    for (final failure in <({String label, Object thrown})>[
      (
        label: 'an Exception',
        thrown: PlatformException(code: 'STORAGE_ERROR'),
      ),
      (label: 'an Error', thrown: StateError('prefs plugin missing')),
    ]) {
      test(
        'a user-blob removal throwing ${failure.label} must still clear the '
        'tokens',
        () async {
          // Arrange - a signed-in device whose prefs removal is broken.
          final store = _FailableKeyValueStore(removeThrows: failure.thrown);
          final tokens = _InMemoryTokenStore()
            ..accessToken = 'access-token'
            ..refreshToken = 'refresh-token';
          final dataSource = AuthLocalDataSourceImpl(
            storageService: store,
            tokenStore: tokens,
          );

          // Act & Assert - the caller is still told the teardown failed...
          await expectLater(
            dataSource.clearCache(),
            throwsA(isA<CacheException>()),
            reason:
                'best-effort is about the other steps running, not about '
                'reporting success',
          );

          // ...and the step after the failing one ran anyway.
          expect(store.removeCalls, 1);
          expect(tokens.clearAllCalls, 1);
          expect(
            await dataSource.getToken(),
            isNull,
            reason:
                'an access token must not survive an explicit logout because '
                'the prefs removal before it threw',
          );
          expect(
            await dataSource.getRefreshToken(),
            isNull,
            reason: 'a live refresh token is the more serious half of this',
          );
        },
      );
    }

    test(
      'a token clear throwing an Error is reported as a CacheException',
      () async {
        // Arrange - the mirror case, and the other half of the `on Exception`
        // defect: the last step failing must not escape the declared contract.
        final store = _FailableKeyValueStore()
          ..values[AppConstants.userDataKey] = '{"id":"1"}';
        final tokens = _FailingTokenStore(StateError('keychain locked'));
        final dataSource = AuthLocalDataSourceImpl(
          storageService: store,
          tokenStore: tokens,
        );

        // Act & Assert
        await expectLater(
          dataSource.clearCache(),
          throwsA(
            isA<CacheException>().having(
              (e) => e.message,
              'message',
              contains('keychain locked'),
            ),
          ),
        );

        // The step before it still took effect.
        expect(store.values.containsKey(AppConstants.userDataKey), isFalse);
        expect(tokens.clearAllCalls, 1);
      },
    );

    test(
      'when both steps fail the first failure is the one reported',
      () async {
        // Arrange
        final store = _FailableKeyValueStore(
          removeThrows: const CacheException('prefs unavailable'),
        );
        final tokens = _FailingTokenStore(StateError('keychain locked'));
        final dataSource = AuthLocalDataSourceImpl(
          storageService: store,
          tokenStore: tokens,
        );

        // Act & Assert
        await expectLater(
          dataSource.clearCache(),
          throwsA(
            isA<CacheException>().having(
              (e) => e.message,
              'message',
              contains('prefs unavailable'),
            ),
          ),
        );

        // Both were attempted regardless.
        expect(store.removeCalls, 1);
        expect(tokens.clearAllCalls, 1);
      },
    );
  });
}
