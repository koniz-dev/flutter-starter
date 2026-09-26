import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for #52: a remote logout that failed short-circuited the
/// local teardown, so the access token, the long-lived refresh token, and the
/// cached user all survived a logout the user believed had happened.
///
/// These drive the real chain - `AuthLocalDataSourceImpl` over in-memory
/// stores, `AuthRepositoryImpl`, the use case, [AuthNotifier], and the router -
/// so what is asserted is the state actually left on the "device", not a mock
/// interaction.

class _InMemoryKeyValueStore implements IKeyValueStore {
  final Map<String, Object?> values = {};

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

  @override
  Future<bool> remove(String key) async {
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
}

class _InMemoryTokenStore implements ITokenStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<bool> setAccessToken(String token) async {
    accessToken = token;
    return true;
  }

  @override
  Future<void> clearAccessToken() async => accessToken = null;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> setRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }

  @override
  Future<void> clearRefreshToken() async => refreshToken = null;

  @override
  Future<void> clearAllTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

/// Remote source whose `logout()` always fails, the way an offline device, a
/// 500, or an adopter who has not implemented `/auth/logout` yet does.
class _FailingRemoteDataSource implements AuthRemoteDataSource {
  _FailingRemoteDataSource(this.error);

  final Object error;
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
    // Rethrowing whatever the caller supplied is the point: the failure shapes
    // under test include an Error, which `only_throw_errors` does not model.
    // ignore: only_throw_errors
    throw error;
  }

  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async => throw UnimplementedError();

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      throw UnimplementedError();
}

/// Stand-in for the HTTP response cache #77 wired into logout.
class _FakeHttpCache implements IHttpResponseCache {
  int clearCalls = 0;

  @override
  Future<void> clearCache() async => clearCalls++;
}

const _user = UserModel(
  id: 'u-1',
  email: 'signed-in@example.com',
  name: 'Signed In User',
);

/// Builds a device that already holds a full session: user blob, access token,
/// and the long-lived refresh token.
({
  _InMemoryKeyValueStore keyValueStore,
  _InMemoryTokenStore tokenStore,
  AuthLocalDataSource localDataSource,
})
_seededDevice() {
  final keyValueStore = _InMemoryKeyValueStore();
  final tokenStore = _InMemoryTokenStore()
    ..accessToken = 'access-token'
    ..refreshToken = 'refresh-token';
  final localDataSource = AuthLocalDataSourceImpl(
    storageService: keyValueStore,
    tokenStore: tokenStore,
  );
  return (
    keyValueStore: keyValueStore,
    tokenStore: tokenStore,
    localDataSource: localDataSource,
  );
}

void main() {
  group('logout tears the local session down even when the remote call '
      'fails (#52)', () {
    // Every realistic failure shape: a modelled AppException, a raw Dio
    // timeout, and an Error - which is not an Exception at all and used to
    // escape the repository entirely.
    final failures = <String, Object>{
      'a NetworkException': const NetworkException('No internet connection'),
      'a 500 ServerException': const ServerException('Internal server error'),
      'a connection timeout': DioException.connectionTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: RequestOptions(path: '/auth/logout'),
      ),
      'an Error': StateError('MissingPluginException'),
    };

    for (final entry in failures.entries) {
      final description = entry.key;
      final error = entry.value;

      test('clears tokens and the cached user after $description', () async {
        // Arrange
        final device = _seededDevice();
        await device.localDataSource.cacheUser(_user);
        final remote = _FailingRemoteDataSource(error);
        final httpCache = _FakeHttpCache();
        final repository = AuthRepositoryImpl(
          remoteDataSource: remote,
          localDataSource: device.localDataSource,
          httpCache: httpCache,
        );
        expect(
          (await repository.isAuthenticated()).dataOrNull,
          isTrue,
          reason: 'precondition: the device holds a session',
        );

        // Act
        final result = await repository.logout();

        // Assert - criterion 3: the remote failure is still reported.
        expect(remote.logoutCalls, 1);
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isNotNull);

        // Criterion 1 + 2: nothing usable is left behind.
        expect(device.tokenStore.accessToken, isNull);
        expect(device.tokenStore.refreshToken, isNull);
        expect(
          device.keyValueStore.values,
          isNot(
            contains(
              AppConstants.userDataKey,
            ),
          ),
        );
        expect(await device.localDataSource.getCachedUser(), isNull);
        expect((await repository.isAuthenticated()).dataOrNull, isFalse);
        // The HTTP response cache is local session state too (#77), so it is
        // dropped on this path as well.
        expect(httpCache.clearCalls, 1);
      });
    }

    test('a successful logout is still reported as a success', () async {
      final device = _seededDevice();
      await device.localDataSource.cacheUser(_user);
      final repository = AuthRepositoryImpl(
        remoteDataSource: _SucceedingRemoteDataSource(),
        localDataSource: device.localDataSource,
      );

      final result = await repository.logout();

      expect(result.isSuccess, isTrue);
      expect(device.tokenStore.accessToken, isNull);
      expect(device.tokenStore.refreshToken, isNull);
      expect((await repository.isAuthenticated()).dataOrNull, isFalse);
    });
  });

  group('a failed logout still redirects to /login (#52)', () {
    setUp(() {
      // `authRepositoryProvider` resolves the real `ApiClient`, whose response
      // cache is backed by SharedPreferences; without the mock the logout
      // teardown awaits a platform channel nothing answers.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('router leaves home for login after the remote call '
        'fails', (tester) async {
      // Arrange - a signed-in device, on the real router.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final device = _seededDevice();
      await device.localDataSource.cacheUser(_user);

      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(device.keyValueStore),
          tokenStoreProvider.overrideWithValue(device.tokenStore),
          authLocalDataSourceProvider.overrideWithValue(device.localDataSource),
          authRemoteDataSourceProvider.overrideWithValue(
            _FailingRemoteDataSource(
              const NetworkException('No internet connection'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionRestorationProvider.future);
      final router = container.read(goRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);

      // Act
      await container.read(authNotifierProvider.notifier).logout();
      await tester.pumpAndSettle();

      // Assert - criterion 4.
      final state = container.read(authNotifierProvider);
      expect(state.user, isNull);
      expect(state.error, isNotNull);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(device.tokenStore.refreshToken, isNull);
    });
  });
}

class _SucceedingRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<void> logout() async {}

  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async => throw UnimplementedError();

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      throw UnimplementedError();
}
