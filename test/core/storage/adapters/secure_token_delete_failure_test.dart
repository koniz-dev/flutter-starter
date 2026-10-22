// A failed Keychain/Keystore delete must not be reported as a clean logout.
//
// SecureStorageService.remove swallows the platform error into `false`, and
// SecureTokenStore's clear methods ignored that bool, so
// AuthRepositoryImpl.logout() returned Success while the refresh token - the
// long-lived credential - was still on the device.

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _NoopRemote implements AuthRemoteDataSource {
  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final keychain = <String, String>{};
  final deleteAttempts = <String>[];

  /// Installs a Keychain whose reads and writes work. A delete of a key in
  /// [failing] throws PlatformException, the way a locked or corrupt
  /// Keychain/Keystore does.
  void installKeychain({Set<String> failing = const {}}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          final key = args?['key'] as String? ?? '';
          switch (call.method) {
            case 'read':
              return keychain[key];
            case 'write':
              keychain[key] = args?['value'] as String? ?? '';
              return null;
            case 'delete':
              deleteAttempts.add(key);
              if (failing.contains(key)) {
                throw PlatformException(code: 'KeychainError');
              }
              keychain.remove(key);
              return null;
          }
          return null;
        });
  }

  setUp(() {
    keychain
      ..clear()
      ..[AppConstants.tokenKey] = 'live-access'
      ..[AppConstants.refreshTokenKey] = 'live-refresh';
    deleteAttempts.clear();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  group('criterion 2: SecureTokenStore.clearAllTokens', () {
    test('attempts both deletes when the first fails, and throws', () async {
      installKeychain(failing: {AppConstants.tokenKey});
      final store = SecureTokenStore(SecureStorageService());

      await expectLater(
        store.clearAllTokens(),
        throwsA(isA<CacheException>()),
      );

      expect(deleteAttempts, [
        AppConstants.tokenKey,
        AppConstants.refreshTokenKey,
      ]);
      // The second delete still ran and succeeded.
      expect(keychain.containsKey(AppConstants.refreshTokenKey), isFalse);
    });

    test('throws when only the refresh-token delete fails', () async {
      installKeychain(failing: {AppConstants.refreshTokenKey});
      final store = SecureTokenStore(SecureStorageService());

      await expectLater(
        store.clearAllTokens(),
        throwsA(isA<CacheException>()),
      );
      expect(keychain[AppConstants.refreshTokenKey], 'live-refresh');
    });

    test('a single clear signals its own failure', () async {
      installKeychain(failing: {AppConstants.refreshTokenKey});
      final store = SecureTokenStore(SecureStorageService());

      await expectLater(
        store.clearRefreshToken(),
        throwsA(isA<CacheException>()),
      );
      await expectLater(store.clearAccessToken(), completes);
    });

    test('succeeds quietly when both deletes work', () async {
      installKeychain();
      final store = SecureTokenStore(SecureStorageService());

      await store.clearAllTokens();

      expect(keychain, isEmpty);
    });
  });

  group('criterion 1: AuthRepositoryImpl.logout surfaces the failure', () {
    Future<(Result<void>, String?)> logOut() async {
      final storage = StorageService();
      await storage.init();
      final store = SecureTokenStore(SecureStorageService());
      final repository = AuthRepositoryImpl(
        remoteDataSource: _NoopRemote(),
        localDataSource: AuthLocalDataSourceImpl(
          storageService: storage,
          tokenStore: store,
        ),
      );
      final result = await repository.logout();
      return (result, await store.getRefreshToken());
    }

    test('a refresh token that survived is a ResultFailure', () async {
      installKeychain(failing: {AppConstants.refreshTokenKey});

      final (result, refresh) = await logOut();

      // ignore: avoid_print - the evidence line for the criterion
      print('VS logout=$result refresh-after=$refresh');
      expect(refresh, 'live-refresh', reason: 'the delete really failed');
      expect(result, isA<ResultFailure<void>>());
    });

    test('a clean delete is still Success', () async {
      installKeychain();

      final (result, refresh) = await logOut();

      expect(result, isA<Success<void>>());
      expect(refresh, isNull);
    });
  });
}
