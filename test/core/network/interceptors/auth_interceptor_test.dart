import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

class FakeDioException extends Fake implements DioException {}

class FakeResponse extends Fake implements Response<dynamic> {}

void main() {
  group('AuthInterceptor', () {
    late AuthInterceptor interceptor;
    late MockSecureStorageService mockSecureStorage;
    late MockAuthRepository mockAuthRepository;

    setUpAll(() {
      registerFallbackValue(FakeDioException());
      registerFallbackValue(FakeResponse());
    });

    setUp(() {
      mockSecureStorage = MockSecureStorageService();
      mockAuthRepository = MockAuthRepository();
      interceptor = AuthInterceptor(
        secureStorageService: mockSecureStorage,
        authRepository: mockAuthRepository,
      );
    });

    group('onRequest', () {
      test('should add Authorization header when token exists', () async {
        const token = 'test_token';
        final options = RequestOptions(path: '/test');
        final handler = RequestInterceptorHandler();

        when(() => mockSecureStorage.getString(AppConstants.tokenKey))
            .thenAnswer((_) async => token);

        await interceptor.onRequest(options, handler);

        expect(options.headers['Authorization'], 'Bearer $token');
      });

      test('should not add Authorization header when token is null', () async {
        final options = RequestOptions(path: '/test');
        final handler = RequestInterceptorHandler();

        when(() => mockSecureStorage.getString(AppConstants.tokenKey))
            .thenAnswer((_) async => null);

        await interceptor.onRequest(options, handler);

        expect(options.headers['Authorization'], isNull);
      });

      test('should not add Authorization header when token is empty', () async {
        final options = RequestOptions(path: '/test');
        final handler = RequestInterceptorHandler();

        when(() => mockSecureStorage.getString(AppConstants.tokenKey))
            .thenAnswer((_) async => '');

        await interceptor.onRequest(options, handler);

        expect(options.headers['Authorization'], isNull);
      });
    });

    group('onError - 401 Handling', () {
      late DioException dioException;
      late MockErrorInterceptorHandler handler;
      late RequestOptions requestOptions;

      setUp(() {
        requestOptions = RequestOptions(path: '/api/user/profile');
        dioException = DioException(
          requestOptions: requestOptions,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 401,
          ),
        );
        handler = MockErrorInterceptorHandler();
      });

      test('should exclude auth endpoints from token refresh', () async {
        final loginException = DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.login),
          response: Response(
            requestOptions: RequestOptions(path: ApiEndpoints.login),
            statusCode: 401,
          ),
        );

        when(() => handler.next(any())).thenReturn(null);

        await interceptor.onError(loginException, handler);

        verify(() => handler.next(loginException)).called(1);
        verifyNever(() => mockAuthRepository.refreshToken());
      });

      test('should trigger token refresh on 401 for non-auth endpoints',
          () async {
        const newToken = 'new_token';

        when(() => mockAuthRepository.refreshToken())
            .thenAnswer((_) async => const Success(newToken));
        when(
          () => mockSecureStorage.setString(
            AppConstants.tokenKey,
            newToken,
          ),
        ).thenAnswer((_) async => true);
        // Mock remove calls in case retry fails and logout is triggered
        when(() => mockSecureStorage.remove(AppConstants.tokenKey))
            .thenAnswer((_) async => true);
        when(() => mockSecureStorage.remove(AppConstants.refreshTokenKey))
            .thenAnswer((_) async => true);
        when(() => handler.resolve(any())).thenReturn(null);
        when(() => handler.reject(any())).thenReturn(null);

        // Note: The retry will likely fail in unit tests since we can't
        // mock Dio, but we verify the refresh token is called
        try {
          await interceptor.onError(dioException, handler);
        } on Exception {
          // Expected - retry fails in unit tests
        }

        verify(() => mockAuthRepository.refreshToken()).called(1);
        verify(
          () => mockSecureStorage.setString(
            AppConstants.tokenKey,
            newToken,
          ),
        ).called(1);
      });

      test('should logout user when refresh fails', () async {
        const failure = AuthFailure('Refresh token expired');

        when(() => mockAuthRepository.refreshToken())
            .thenAnswer((_) async => const ResultFailure(failure));
        when(() => mockSecureStorage.remove(AppConstants.tokenKey))
            .thenAnswer((_) async => true);
        when(() => mockSecureStorage.remove(AppConstants.refreshTokenKey))
            .thenAnswer((_) async => true);
        when(() => handler.reject(any())).thenReturn(null);

        await interceptor.onError(dioException, handler);

        verify(() => mockAuthRepository.refreshToken()).called(1);
        verify(() => mockSecureStorage.remove(AppConstants.tokenKey)).called(1);
        verify(() => mockSecureStorage.remove(AppConstants.refreshTokenKey))
            .called(1);
        verify(() => handler.reject(any())).called(1);
      });

      test('should prevent infinite retry loop', () async {
        final retryRequestOptions = requestOptions.copyWith(
          headers: {
            ...requestOptions.headers,
            'X-Retry-Count': '1',
          },
        );
        final retryException = DioException(
          requestOptions: retryRequestOptions,
          response: Response(
            requestOptions: retryRequestOptions,
            statusCode: 401,
          ),
        );

        when(() => mockSecureStorage.remove(AppConstants.tokenKey))
            .thenAnswer((_) async => true);
        when(() => mockSecureStorage.remove(AppConstants.refreshTokenKey))
            .thenAnswer((_) async => true);
        when(() => handler.reject(any())).thenReturn(null);

        await interceptor.onError(retryException, handler);

        verifyNever(() => mockAuthRepository.refreshToken());
        verify(() => mockSecureStorage.remove(AppConstants.tokenKey)).called(1);
        verify(() => handler.reject(retryException)).called(1);
      });

      test('should queue requests during refresh', () async {
        const newToken = 'new_token';
        final handler1 = MockErrorInterceptorHandler();
        final handler2 = MockErrorInterceptorHandler();

        // First request starts refresh
        when(() => mockAuthRepository.refreshToken())
            .thenAnswer((_) async => const Success(newToken));
        when(
          () => mockSecureStorage.setString(
            AppConstants.tokenKey,
            newToken,
          ),
        ).thenAnswer((_) async => true);
        // Mock remove calls in case retry fails
        when(() => mockSecureStorage.remove(AppConstants.tokenKey))
            .thenAnswer((_) async => true);
        when(() => mockSecureStorage.remove(AppConstants.refreshTokenKey))
            .thenAnswer((_) async => true);
        when(() => handler1.resolve(any())).thenReturn(null);
        when(() => handler1.reject(any())).thenReturn(null);
        when(() => handler2.resolve(any())).thenReturn(null);
        when(() => handler2.reject(any())).thenReturn(null);

        // Start first request (will trigger refresh)
        final future1 = interceptor.onError(dioException, handler1);

        // Second request should be queued
        final future2 = interceptor.onError(dioException, handler2);

        // Wait for both to complete (may throw due to retry failure)
        try {
          await future1;
          await future2;
        } on Exception {
          // Expected - retry fails in unit tests
        }

        // Refresh should only be called once
        verify(() => mockAuthRepository.refreshToken()).called(1);
      });

      test('should handle exception during refresh', () async {
        when(() => mockAuthRepository.refreshToken())
            .thenThrow(Exception('Network error'));
        when(() => mockSecureStorage.remove(AppConstants.tokenKey))
            .thenAnswer((_) async => true);
        when(() => mockSecureStorage.remove(AppConstants.refreshTokenKey))
            .thenAnswer((_) async => true);
        when(() => handler.reject(any())).thenReturn(null);

        await interceptor.onError(dioException, handler);

        verify(() => mockSecureStorage.remove(AppConstants.tokenKey)).called(1);
        verify(() => handler.reject(any())).called(1);
      });
    });

    group('onError - Non-401 Errors', () {
      test('should pass through non-401 errors', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 500,
          ),
        );
        final handler = MockErrorInterceptorHandler();

        when(() => handler.next(any())).thenReturn(null);

        await interceptor.onError(dioException, handler);

        verifyNever(() => mockAuthRepository.refreshToken());
        verify(() => handler.next(dioException)).called(1);
      });

      test('should pass through 400 errors', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 400,
          ),
        );
        final handler = MockErrorInterceptorHandler();

        when(() => handler.next(any())).thenReturn(null);

        await interceptor.onError(dioException, handler);

        verifyNever(() => mockAuthRepository.refreshToken());
        verify(() => handler.next(dioException)).called(1);
      });

      test('should pass through 403 errors', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 403,
          ),
        );
        final handler = MockErrorInterceptorHandler();

        when(() => handler.next(any())).thenReturn(null);

        await interceptor.onError(dioException, handler);

        verifyNever(() => mockAuthRepository.refreshToken());
        verify(() => handler.next(dioException)).called(1);
      });

      test('should pass through errors without response', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );
        final handler = MockErrorInterceptorHandler();

        when(() => handler.next(any())).thenReturn(null);

        await interceptor.onError(dioException, handler);

        verifyNever(() => mockAuthRepository.refreshToken());
        verify(() => handler.next(dioException)).called(1);
      });
    });

    group('Edge Cases', () {
      test('should handle multiple excluded endpoints', () async {
        final excludedPaths = [
          ApiEndpoints.login,
          ApiEndpoints.register,
          ApiEndpoints.refreshToken,
          ApiEndpoints.logout,
        ];

        for (final path in excludedPaths) {
          final dioException = DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 401,
            ),
          );
          final handler = MockErrorInterceptorHandler();

          when(() => handler.next(any())).thenReturn(null);

          await interceptor.onError(dioException, handler);

          verifyNever(() => mockAuthRepository.refreshToken());
        }
      });

      test('should handle token with special characters', () async {
        const token = r'token-with-special-chars-!@#$%^&*()';
        final options = RequestOptions(path: '/test');
        final handler = RequestInterceptorHandler();

        when(() => mockSecureStorage.getString(AppConstants.tokenKey))
            .thenAnswer((_) async => token);

        await interceptor.onRequest(options, handler);

        expect(options.headers['Authorization'], 'Bearer $token');
      });

      test('should handle very long token', () async {
        final longToken = 'A' * 1000;
        final options = RequestOptions(path: '/test');
        final handler = RequestInterceptorHandler();

        when(() => mockSecureStorage.getString(AppConstants.tokenKey))
            .thenAnswer((_) async => longToken);

        await interceptor.onRequest(options, handler);

        expect(options.headers['Authorization'], 'Bearer $longToken');
      });

      test('should handle whitespace-only token', () async {
        const token = '   ';
        final options = RequestOptions(path: '/test');
        final handler = RequestInterceptorHandler();

        when(() => mockSecureStorage.getString(AppConstants.tokenKey))
            .thenAnswer((_) async => token);

        await interceptor.onRequest(options, handler);

        // Token with only whitespace should still be added
        expect(options.headers['Authorization'], 'Bearer $token');
      });
    });
  });
}
