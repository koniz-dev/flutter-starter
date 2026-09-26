import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for error handling flow
///
/// Tests the complete error handling flow:
/// DioException → AppException → Failure → Result
void main() {
  group('Error Handling Flow Integration', () {
    test('should handle network error flow correctly', () {
      // Arrange - Simulate DioException from network
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timeout',
      );

      // Act - Convert through the flow
      final domainException = DioExceptionMapper.map(dioException);
      final failure = ExceptionToFailureMapper.map(domainException);
      final result = ResultFailure<String>(failure);

      // Assert - Verify each step
      expect(domainException, isA<NetworkException>());
      expect(failure, isA<NetworkFailure>());
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(result.failureOrNull?.message, contains('Connection timeout'));
    });

    test('should handle server error flow correctly', () {
      // Arrange - Simulate DioException from server
      final response = Response(
        requestOptions: RequestOptions(path: '/api/test'),
        statusCode: 500,
        data: {'message': 'Internal server error'},
      );
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        type: DioExceptionType.badResponse,
        response: response,
      );

      // Act - Convert through the flow
      final domainException = DioExceptionMapper.map(dioException);
      final failure = ExceptionToFailureMapper.map(domainException);
      final result = ResultFailure<String>(failure);

      // Assert - Verify each step
      expect(domainException, isA<ServerException>());
      expect((domainException as ServerException).statusCode, 500);
      expect(failure, isA<ServerFailure>());
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ServerFailure>());
    });

    test('should preserve error codes through the flow', () {
      // Arrange
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        type: DioExceptionType.connectionError,
        message: 'Connection error',
      );

      // Act
      final domainException = DioExceptionMapper.map(dioException);
      final failure = ExceptionToFailureMapper.map(domainException);
      final result = ResultFailure<String>(failure);

      // Assert
      expect(domainException.code, isNotNull);
      expect(failure.code, domainException.code);
      expect(result.failureOrNull?.code, failure.code);
    });

    test('should handle cache error flow correctly', () {
      // Arrange - Simulate CacheException
      const cacheException = CacheException(
        'Failed to cache data',
        code: 'CACHE_ERROR',
      );

      // Act - Convert to failure
      final failure = ExceptionToFailureMapper.map(cacheException);
      final result = ResultFailure<String>(failure);

      // Assert
      expect(failure, isA<CacheFailure>());
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<CacheFailure>());
      expect(result.failureOrNull?.message, 'Failed to cache data');
      expect(result.failureOrNull?.code, 'CACHE_ERROR');
    });

    test('should handle auth error flow correctly', () {
      // Arrange - Simulate AuthException
      const authException = AuthException(
        'Authentication failed',
        code: 'AUTH_ERROR',
      );

      // Act - Convert to failure
      final failure = ExceptionToFailureMapper.map(authException);
      final result = ResultFailure<String>(failure);

      // Assert
      expect(failure, isA<AuthFailure>());
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('should handle unknown exception flow correctly', () {
      // Arrange - Simulate unknown exception
      final unknownException = Exception('Unexpected error');

      // Act - Convert to failure
      final failure = ExceptionToFailureMapper.map(unknownException);
      final result = ResultFailure<String>(failure);

      // Assert
      expect(failure, isA<UnknownFailure>());
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<UnknownFailure>());
      expect(result.failureOrNull?.message, contains('Unexpected error'));
    });
  });
}
