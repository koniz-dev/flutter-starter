import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('SecureTokenStore', () {
    late _MockSecureStorageService secureStorage;
    late SecureTokenStore store;

    setUp(() {
      secureStorage = _MockSecureStorageService();
      store = SecureTokenStore(secureStorage);
    });

    test('getAccessToken should read AppConstants.tokenKey', () async {
      when(() => secureStorage.getString(any())).thenAnswer((_) async => 't');
      final token = await store.getAccessToken();
      expect(token, 't');
      verify(() => secureStorage.getString(AppConstants.tokenKey)).called(1);
    });

    test('setAccessToken should write AppConstants.tokenKey', () async {
      when(
        () => secureStorage.setString(any(), any()),
      ).thenAnswer((_) async => true);
      final ok = await store.setAccessToken('t');
      expect(ok, isTrue);
      verify(
        () => secureStorage.setString(AppConstants.tokenKey, 't'),
      ).called(1);
    });

    test('clearAccessToken should remove AppConstants.tokenKey', () async {
      when(() => secureStorage.remove(any())).thenAnswer((_) async => true);
      await store.clearAccessToken();
      verify(() => secureStorage.remove(AppConstants.tokenKey)).called(1);
    });

    test('getRefreshToken should read AppConstants.refreshTokenKey', () async {
      when(() => secureStorage.getString(any())).thenAnswer((_) async => 'rt');
      final token = await store.getRefreshToken();
      expect(token, 'rt');
      verify(
        () => secureStorage.getString(AppConstants.refreshTokenKey),
      ).called(1);
    });

    test('setRefreshToken should write AppConstants.refreshTokenKey', () async {
      when(
        () => secureStorage.setString(any(), any()),
      ).thenAnswer((_) async => true);
      final ok = await store.setRefreshToken('rt');
      expect(ok, isTrue);
      verify(
        () => secureStorage.setString(AppConstants.refreshTokenKey, 'rt'),
      ).called(1);
    });

    test(
      'clearRefreshToken should remove AppConstants.refreshTokenKey',
      () async {
        when(() => secureStorage.remove(any())).thenAnswer((_) async => true);
        await store.clearRefreshToken();
        verify(
          () => secureStorage.remove(AppConstants.refreshTokenKey),
        ).called(1);
      },
    );

    test(
      'clearAllTokens should clear both access and refresh tokens',
      () async {
        when(() => secureStorage.remove(any())).thenAnswer((_) async => true);

        await store.clearAllTokens();

        verify(() => secureStorage.remove(AppConstants.tokenKey)).called(1);
        verify(
          () => secureStorage.remove(AppConstants.refreshTokenKey),
        ).called(1);
      },
    );
  });
}
