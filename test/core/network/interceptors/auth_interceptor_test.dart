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

void main() {
  group('AuthInterceptor', () {
    late AuthInterceptor interceptor;
    late MockSecureStorageService mockSecureStorage;
    late MockAuthRepository mockAuthRepository;

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

        await interceptor.onError(loginException, handler);

        verify(() => handler.reject(loginException)).called(1);
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

        // Note: We can't easily mock the internal Dio request retry,
        // so we test the flow by verifying the refresh token is called
        // The actual retry will fail in unit tests, but that's expected

        await interceptor.onError(dioException, handler);

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

        // Start first request (will trigger refresh)
        final future1 = interceptor.onError(dioException, handler1);

        // Second request should be queued
        final future2 = interceptor.onError(dioException, handler2);

        // Wait for both to complete
        await future1;
        await future2;

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

        await interceptor.onError(dioException, handler);

        verifyNever(() => mockAuthRepository.refreshToken());
        verify(() => handler.reject(dioException)).called(1);
      });
    });
  });
}
