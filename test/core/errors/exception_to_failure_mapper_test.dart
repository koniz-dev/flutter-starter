import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExceptionToFailureMapper', () {
    group('ServerException', () {
      test('should map ServerException to ServerFailure', () {
        const exception = ServerException(
          'Server error occurred',
          code: 'SERVER_ERROR',
          statusCode: 500,
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ServerFailure>());
        expect(result.message, 'Server error occurred');
        expect(result.code, 'SERVER_ERROR');
      });

      test('should preserve message and code', () {
        const exception = ServerException(
          'Custom server message',
          code: 'CUSTOM_CODE',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result.message, 'Custom server message');
        expect(result.code, 'CUSTOM_CODE');
      });
    });

    group('NetworkException', () {
      test('should map NetworkException to NetworkFailure', () {
        const exception = NetworkException(
          'Network error occurred',
          code: 'NETWORK_ERROR',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<NetworkFailure>());
        expect(result.message, 'Network error occurred');
        expect(result.code, 'NETWORK_ERROR');
      });

      test('should preserve message and code', () {
        const exception = NetworkException(
          'Connection timeout',
          code: 'TIMEOUT',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result.message, 'Connection timeout');
        expect(result.code, 'TIMEOUT');
      });
    });

    group('CacheException', () {
      test('should map CacheException to CacheFailure', () {
        const exception = CacheException(
          'Cache error occurred',
          code: 'CACHE_ERROR',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<CacheFailure>());
        expect(result.message, 'Cache error occurred');
        expect(result.code, 'CACHE_ERROR');
      });

      test('should preserve message and code', () {
        const exception = CacheException(
          'Failed to read cache',
          code: 'READ_ERROR',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result.message, 'Failed to read cache');
        expect(result.code, 'READ_ERROR');
      });
    });

    group('AuthException', () {
      test('should map AuthException to AuthFailure', () {
        const exception = AuthException(
          'Authentication failed',
          code: 'AUTH_ERROR',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<AuthFailure>());
        expect(result.message, 'Authentication failed');
        expect(result.code, 'AUTH_ERROR');
      });

      test('should preserve message and code', () {
        const exception = AuthException(
          'Invalid credentials',
          code: 'INVALID_CREDENTIALS',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result.message, 'Invalid credentials');
        expect(result.code, 'INVALID_CREDENTIALS');
      });
    });

    group('ValidationException', () {
      test('should map ValidationException to ValidationFailure', () {
        const exception = ValidationException(
          'Validation failed',
          code: 'VALIDATION_ERROR',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ValidationFailure>());
        expect(result.message, 'Validation failed');
        expect(result.code, 'VALIDATION_ERROR');
      });

      test('should preserve message and code', () {
        const exception = ValidationException(
          'Email is required',
          code: 'EMAIL_REQUIRED',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result.message, 'Email is required');
        expect(result.code, 'EMAIL_REQUIRED');
      });
    });

    group('Unknown Exception', () {
      test('should map unknown exception to UnknownFailure', () {
        final exception = Exception('Unexpected error');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<UnknownFailure>());
        expect(result.message, contains('Unexpected error'));
        expect(result.code, 'UNKNOWN_ERROR');
      });

      test('should include exception string in message', () {
        const exception = FormatException('Invalid format');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<UnknownFailure>());
        expect(result.message, contains('Unexpected error'));
        expect(result.message, contains('FormatException'));
      });
    });

    group('Null Code Handling', () {
      test('should handle exceptions with null code', () {
        const exception = ServerException('Error without code');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ServerFailure>());
        expect(result.message, 'Error without code');
        expect(result.code, isNull);
      });

      test('should handle NetworkException with null code', () {
        const exception = NetworkException('Network error without code');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<NetworkFailure>());
        expect(result.message, 'Network error without code');
        expect(result.code, isNull);
      });

      test('should handle CacheException with null code', () {
        const exception = CacheException('Cache error without code');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<CacheFailure>());
        expect(result.message, 'Cache error without code');
        expect(result.code, isNull);
      });

      test('should handle AuthException with null code', () {
        const exception = AuthException('Auth error without code');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<AuthFailure>());
        expect(result.message, 'Auth error without code');
        expect(result.code, isNull);
      });

      test('should handle ValidationException with null code', () {
        const exception = ValidationException('Validation error without code');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ValidationFailure>());
        expect(result.message, 'Validation error without code');
        expect(result.code, isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle empty message', () {
        const exception = ServerException('');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ServerFailure>());
        expect(result.message, isEmpty);
      });

      test('should handle long messages', () {
        final longMessage = 'A' * 1000;
        final exception = ServerException(longMessage);

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ServerFailure>());
        expect(result.message.length, 1000);
      });

      test('should handle all exception types', () {
        final exceptions = [
          const ServerException('Server error'),
          const NetworkException('Network error'),
          const CacheException('Cache error'),
          const AuthException('Auth error'),
          const ValidationException('Validation error'),
          Exception('Generic error'),
        ];

        for (final exception in exceptions) {
          final result = ExceptionToFailureMapper.map(exception);
          expect(result, isA<Failure>());
          expect(result.message, isNotEmpty);
        }
      });

      test('should handle exceptions with special characters in message', () {
        const exception = ServerException(
          r'Error: "Special chars: @#\$%^&*()',
          code: 'SPECIAL',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ServerFailure>());
        expect(result.message, contains('Special chars'));
      });

      test('should handle exceptions with unicode characters', () {
        const exception = NetworkException(
          '网络错误: 连接超时',
          code: 'UNICODE',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<NetworkFailure>());
        expect(result.message, contains('网络'));
      });

      test('should handle exceptions with newlines in message', () {
        const exception = CacheException(
          'Error line 1\nError line 2\nError line 3',
          code: 'MULTILINE',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<CacheFailure>());
        expect(result.message, contains('\n'));
      });

      test('should handle exceptions with whitespace-only message', () {
        const exception = AuthException('   ', code: 'WHITESPACE');

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<AuthFailure>());
        expect(result.message, '   ');
      });

      test('should handle exceptions with very long code', () {
        const exception = ValidationException(
          'Validation error',
          code: 'VERY_LONG_CODE',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result, isA<ValidationFailure>());
        expect(result.code, 'VERY_LONG_CODE');
      });
    });

    group('Switch Expression Coverage', () {
      test('should use pattern matching for all exception types', () {
        // Test that all exception types are handled by the switch expression
        const serverException = ServerException('test');
        final serverResult = ExceptionToFailureMapper.map(serverException);
        expect(serverResult, isA<ServerFailure>());

        const networkException = NetworkException('test');
        final networkResult = ExceptionToFailureMapper.map(networkException);
        expect(networkResult, isA<NetworkFailure>());

        const cacheException = CacheException('test');
        final cacheResult = ExceptionToFailureMapper.map(cacheException);
        expect(cacheResult, isA<CacheFailure>());

        const authException = AuthException('test');
        final authResult = ExceptionToFailureMapper.map(authException);
        expect(authResult, isA<AuthFailure>());

        const validationException = ValidationException('test');
        final validationResult = ExceptionToFailureMapper.map(
          validationException,
        );
        expect(validationResult, isA<ValidationFailure>());

        final unknownException = Exception('test');
        final unknownResult = ExceptionToFailureMapper.map(unknownException);
        expect(unknownResult, isA<UnknownFailure>());
      });

      test('should extract message and code from pattern matching', () {
        const exception = ServerException(
          'Test message',
          code: 'TEST_CODE',
        );

        final result = ExceptionToFailureMapper.map(exception);

        expect(result.message, 'Test message');
        expect(result.code, 'TEST_CODE');
      });
    });
  });
}
