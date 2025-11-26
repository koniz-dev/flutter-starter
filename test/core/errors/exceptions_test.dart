import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppException', () {
    test('should create exception with message', () {
      // Arrange & Act
      const exception = TestAppException('Test message');

      // Assert
      expect(exception.message, 'Test message');
      expect(exception.code, isNull);
    });

    test('should create exception with message and code', () {
      // Arrange & Act
      const exception = TestAppException('Test message', code: 'TEST_CODE');

      // Assert
      expect(exception.message, 'Test message');
      expect(exception.code, 'TEST_CODE');
    });
  });

  group('ServerException', () {
    test('should create ServerException with message', () {
      // Arrange & Act
      const exception = ServerException('Server error');

      // Assert
      expect(exception.message, 'Server error');
      expect(exception.code, isNull);
      expect(exception.statusCode, isNull);
    });

    test('should create ServerException with message and statusCode', () {
      // Arrange & Act
      const exception = ServerException(
        'Not found',
        code: '404',
        statusCode: 404,
      );

      // Assert
      expect(exception.message, 'Not found');
      expect(exception.code, '404');
      expect(exception.statusCode, 404);
    });

    test('should extend AppException', () {
      // Arrange & Act
      const exception = ServerException('Error');

      // Assert
      expect(exception, isA<AppException>());
    });
  });

  group('NetworkException', () {
    test('should create NetworkException with message', () {
      // Arrange & Act
      const exception = NetworkException('Network error');

      // Assert
      expect(exception.message, 'Network error');
      expect(exception.code, isNull);
    });

    test('should create NetworkException with message and code', () {
      // Arrange & Act
      const exception = NetworkException(
        'Connection timeout',
        code: 'TIMEOUT',
      );

      // Assert
      expect(exception.message, 'Connection timeout');
      expect(exception.code, 'TIMEOUT');
    });

    test('should extend AppException', () {
      // Arrange & Act
      const exception = NetworkException('Error');

      // Assert
      expect(exception, isA<AppException>());
    });
  });

  group('CacheException', () {
    test('should create CacheException with message', () {
      // Arrange & Act
      const exception = CacheException('Cache error');

      // Assert
      expect(exception.message, 'Cache error');
      expect(exception.code, isNull);
    });

    test('should create CacheException with message and code', () {
      // Arrange & Act
      const exception = CacheException('Storage full', code: 'STORAGE_FULL');

      // Assert
      expect(exception.message, 'Storage full');
      expect(exception.code, 'STORAGE_FULL');
    });

    test('should extend AppException', () {
      // Arrange & Act
      const exception = CacheException('Error');

      // Assert
      expect(exception, isA<AppException>());
    });
  });

  group('ValidationException', () {
    test('should create ValidationException with message', () {
      // Arrange & Act
      const exception = ValidationException('Validation error');

      // Assert
      expect(exception.message, 'Validation error');
      expect(exception.code, isNull);
    });

    test('should create ValidationException with message and code', () {
      // Arrange & Act
      const exception = ValidationException(
        'Invalid email',
        code: 'INVALID_EMAIL',
      );

      // Assert
      expect(exception.message, 'Invalid email');
      expect(exception.code, 'INVALID_EMAIL');
    });

    test('should extend AppException', () {
      // Arrange & Act
      const exception = ValidationException('Error');

      // Assert
      expect(exception, isA<AppException>());
    });
  });

  group('AuthException', () {
    test('should create AuthException with message', () {
      // Arrange & Act
      const exception = AuthException('Auth error');

      // Assert
      expect(exception.message, 'Auth error');
      expect(exception.code, isNull);
    });

    test('should create AuthException with message and code', () {
      // Arrange & Act
      const exception = AuthException('Unauthorized', code: 'UNAUTHORIZED');

      // Assert
      expect(exception.message, 'Unauthorized');
      expect(exception.code, 'UNAUTHORIZED');
    });

    test('should extend AppException', () {
      // Arrange & Act
      const exception = AuthException('Error');

      // Assert
      expect(exception, isA<AppException>());
    });
  });

  group('Edge Cases', () {
    test('ServerException should handle null statusCode', () {
      const exception = ServerException('Error');
      expect(exception.statusCode, isNull);
    });

    test('ServerException should handle various status codes', () {
      const statusCodes = [400, 401, 403, 404, 500, 502, 503];
      for (final code in statusCodes) {
        final exception = ServerException('Error', statusCode: code);
        expect(exception.statusCode, code);
      }
    });

    test('All exceptions should implement Exception interface', () {
      expect(const ServerException('Error'), isA<Exception>());
      expect(const NetworkException('Error'), isA<Exception>());
      expect(const CacheException('Error'), isA<Exception>());
      expect(const ValidationException('Error'), isA<Exception>());
      expect(const AuthException('Error'), isA<Exception>());
    });

    test('Exceptions should handle empty message', () {
      const exception = ServerException('');
      expect(exception.message, isEmpty);
    });

    test('Exceptions should handle long messages', () {
      final longMessage = 'A' * 1000;
      final exception = ServerException(longMessage);
      expect(exception.message.length, 1000);
    });

    test('ValidationException should be accessible', () {
      const exception = ValidationException('Test');
      expect(exception, isA<ValidationException>());
      expect(exception, isA<AppException>());
    });

    test('AuthException should be accessible', () {
      const exception = AuthException('Test');
      expect(exception, isA<AuthException>());
      expect(exception, isA<AppException>());
    });
  });
}

// Test implementation of AppException for testing
class TestAppException extends AppException {
  const TestAppException(super.message, {super.code});
}
