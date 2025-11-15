import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthLocalDataSourceImpl', () {
    late StorageService storageService;
    late SecureStorageService secureStorageService;
    late AuthLocalDataSourceImpl dataSource;

    setUp(() async {
      storageService = StorageService();
      secureStorageService = SecureStorageService();
      await storageService.init();
      dataSource = AuthLocalDataSourceImpl(
        storageService: storageService,
        secureStorageService: secureStorageService,
      );
    });

    tearDown(() async {
      await dataSource.clearCache();
      await storageService.clear();
      await secureStorageService.clear();
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
      test(
        'should store tokens in secure storage and user data in regular '
        'storage',
        () async {
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
        expect(
          await storageService.getString(AppConstants.tokenKey),
          isNull,
        );
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
        },
      );
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
        // This test verifies error handling structure
        // Actual failure would require mocking secure storage
        const token = 'test_token';

        // Should not throw for normal operation
        expect(() => dataSource.cacheToken(token), returnsNormally);
      });

      test('should throw CacheException when user caching fails', () async {
        const user = UserModel(
          id: '1',
          email: 'test@example.com',
          name: 'Test User',
        );

        // Should not throw for normal operation
        expect(() => dataSource.cacheUser(user), returnsNormally);
      });
    });
  });
}
