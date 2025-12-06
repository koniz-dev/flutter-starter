import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_factories.dart';
import '../../helpers/test_fixtures.dart';

/// Test handler for error interceptor
class TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  TestErrorInterceptorHandler() : super();

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = true]) {
    // Don't call super.reject() to avoid async completion issues in tests
  }

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingResponseInterceptor = true,
  ]) {
    // Not used in error interceptor tests
  }

  @override
  void next(DioException err) {
    // Don't call super.next() to avoid async completion issues in tests
    // Just store the error for verification
    _nextError = err;
  }

  DioException? _nextError;
  DioException? get nextError => _nextError;
}

/// Integration test for token refresh flow
///
/// Tests the complete token refresh flow:
/// 401 Error → Token Refresh → Retry Request
void main() {
  group('Token Refresh Flow Integration', () {
    late AuthInterceptor interceptor;
    late MockAuthRepository mockAuthRepository;
    late MockSecureStorageService mockSecureStorage;

    setUp(() {
      mockAuthRepository = createMockAuthRepository();
      mockSecureStorage = createMockSecureStorageService();
      interceptor = AuthInterceptor(
        secureStorageService: mockSecureStorage,
        authRepository: mockAuthRepository,
      );
    });

    test('should refresh token on 401 error', () async {
      // Arrange
      const refreshToken = 'refresh-token';
      const newAccessToken = 'new-access-token';
      final requestOptions = RequestOptions(path: '/api/protected');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
        ),
      );

      when(
        () => mockSecureStorage.getString(AppConstants.refreshTokenKey),
      ).thenAnswer((_) async => refreshToken);
      when(
        () => mockAuthRepository.refreshToken(),
      ).thenAnswer((_) async => const Success(newAccessToken));
      when(
        () => mockSecureStorage.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockSecureStorage.remove(any())).thenAnswer((_) async => true);

      // Act
      await interceptor.onError(
        dioException,
        TestErrorInterceptorHandler(),
      );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(() => mockAuthRepository.refreshToken()).called(1);
    });

    test('should not refresh token for excluded endpoints', () async {
      // Arrange
      final requestOptions = RequestOptions(path: '/auth/login');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
        ),
      );
      final handler = TestErrorInterceptorHandler();

      // Act
      await interceptor.onError(dioException, handler);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      verifyNever(() => mockAuthRepository.refreshToken());
      // Verify that the error was passed through (not handled)
      expect(handler.nextError, isNotNull);
    });

    test('should logout user when refresh fails', () async {
      // Arrange
      const refreshToken = 'refresh-token';
      final requestOptions = RequestOptions(path: '/api/protected');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
        ),
      );

      when(
        () => mockSecureStorage.getString(AppConstants.refreshTokenKey),
      ).thenAnswer((_) async => refreshToken);
      final failure = createAuthFailure(message: 'Refresh token expired');
      when(
        () => mockAuthRepository.refreshToken(),
      ).thenAnswer((_) async => ResultFailure(failure));
      when(() => mockSecureStorage.remove(any())).thenAnswer((_) async => true);

      // Act
      await interceptor.onError(
        dioException,
        TestErrorInterceptorHandler(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(() => mockAuthRepository.refreshToken()).called(1);
      verify(() => mockSecureStorage.remove(AppConstants.tokenKey)).called(1);
      verify(
        () => mockSecureStorage.remove(AppConstants.refreshTokenKey),
      ).called(1);
    });
  });
}
