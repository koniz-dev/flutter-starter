import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure', () {
    test('should create failure with message', () {
      // Arrange & Act
      const failure = TestFailure('Test message');

      // Assert
      expect(failure.message, 'Test message');
      expect(failure.code, isNull);
    });

    test('should create failure with message and code', () {
      // Arrange & Act
      const failure = TestFailure('Test message', code: 'TEST_CODE');

      // Assert
      expect(failure.message, 'Test message');
      expect(failure.code, 'TEST_CODE');
    });

    test('should be equatable', () {
      // Arrange
      const failure1 = TestFailure('Error', code: 'CODE');
      const failure2 = TestFailure('Error', code: 'CODE');
      const failure3 = TestFailure('Different', code: 'CODE');

      // Assert
      expect(failure1, equals(failure2));
      expect(failure1, isNot(equals(failure3)));
    });
  });

  group('ServerFailure', () {
    test('should create ServerFailure with message', () {
      // Arrange & Act
      const failure = ServerFailure('Server error');

      // Assert
      expect(failure.message, 'Server error');
      expect(failure.code, isNull);
    });

    test('should create ServerFailure with message and code', () {
      // Arrange & Act
      const failure = ServerFailure('Not found', code: '404');

      // Assert
      expect(failure.message, 'Not found');
      expect(failure.code, '404');
    });

    test('should extend Failure', () {
      // Arrange & Act
      const failure = ServerFailure('Error');

      // Assert
      expect(failure, isA<Failure>());
    });
  });

  group('NetworkFailure', () {
    test('should create NetworkFailure with message', () {
      // Arrange & Act
      const failure = NetworkFailure('Network error');

      // Assert
      expect(failure.message, 'Network error');
      expect(failure.code, isNull);
    });

    test('should create NetworkFailure with message and code', () {
      // Arrange & Act
      const failure = NetworkFailure('Connection timeout', code: 'TIMEOUT');

      // Assert
      expect(failure.message, 'Connection timeout');
      expect(failure.code, 'TIMEOUT');
    });

    test('should extend Failure', () {
      // Arrange & Act
      const failure = NetworkFailure('Error');

      // Assert
      expect(failure, isA<Failure>());
    });
  });

  group('CacheFailure', () {
    test('should create CacheFailure with message', () {
      // Arrange & Act
      const failure = CacheFailure('Cache error');

      // Assert
      expect(failure.message, 'Cache error');
      expect(failure.code, isNull);
    });

    test('should create CacheFailure with message and code', () {
      // Arrange & Act
      const failure = CacheFailure('Storage full', code: 'STORAGE_FULL');

      // Assert
      expect(failure.message, 'Storage full');
      expect(failure.code, 'STORAGE_FULL');
    });

    test('should extend Failure', () {
      // Arrange & Act
      const failure = CacheFailure('Error');

      // Assert
      expect(failure, isA<Failure>());
    });
  });

  group('ValidationFailure', () {
    test('should create ValidationFailure with message', () {
      // Arrange & Act
      const failure = ValidationFailure('Validation error');

      // Assert
      expect(failure.message, 'Validation error');
      expect(failure.code, isNull);
    });

    test('should create ValidationFailure with message and code', () {
      // Arrange & Act
      const failure = ValidationFailure('Invalid email', code: 'INVALID_EMAIL');

      // Assert
      expect(failure.message, 'Invalid email');
      expect(failure.code, 'INVALID_EMAIL');
    });

    test('should extend Failure', () {
      // Arrange & Act
      const failure = ValidationFailure('Error');

      // Assert
      expect(failure, isA<Failure>());
    });
  });

  group('AuthFailure', () {
    test('should create AuthFailure with message', () {
      // Arrange & Act
      const failure = AuthFailure('Auth error');

      // Assert
      expect(failure.message, 'Auth error');
      expect(failure.code, isNull);
    });

    test('should create AuthFailure with message and code', () {
      // Arrange & Act
      const failure = AuthFailure('Unauthorized', code: 'UNAUTHORIZED');

      // Assert
      expect(failure.message, 'Unauthorized');
      expect(failure.code, 'UNAUTHORIZED');
    });

    test('should extend Failure', () {
      // Arrange & Act
      const failure = AuthFailure('Error');

      // Assert
      expect(failure, isA<Failure>());
    });
  });

  group('PermissionFailure', () {
    test('should create PermissionFailure with message', () {
      // Arrange & Act
      const failure = PermissionFailure('Permission denied');

      // Assert
      expect(failure.message, 'Permission denied');
      expect(failure.code, isNull);
    });

    test('should create PermissionFailure with message and code', () {
      // Arrange & Act
      const failure = PermissionFailure(
        'Access denied',
        code: 'ACCESS_DENIED',
      );

      // Assert
      expect(failure.message, 'Access denied');
      expect(failure.code, 'ACCESS_DENIED');
    });

    test('should extend Failure', () {
      // Arrange & Act
      const failure = PermissionFailure('Error');

      // Assert
      expect(failure, isA<Failure>());
    });
  });

  group('UnknownFailure', () {
    test('should create UnknownFailure with message', () {
      // Arrange & Act
      const failure = UnknownFailure('Unknown error');

      // Assert
      expect(failure.message, 'Unknown error');
      expect(failure.code, isNull);
    });

    test('should create UnknownFailure with message and code', () {
      // Arrange & Act
      const failure = UnknownFailure('Unexpected error', code: 'UNEXPECTED');

      // Assert
      expect(failure.message, 'Unexpected error');
      expect(failure.code, 'UNEXPECTED');
    });

    test('should extend Failure', () {
      // Arrange & Act
      const failure = UnknownFailure('Error');

      // Assert
      expect(failure, isA<Failure>());
    });
  });

  group('Equality Tests', () {
    test('failures with same message and code should be equal', () {
      const failure1 = ServerFailure('Error', code: 'CODE');
      const failure2 = ServerFailure('Error', code: 'CODE');
      expect(failure1, equals(failure2));
    });

    test('failures with different messages should not be equal', () {
      const failure1 = ServerFailure('Error 1', code: 'CODE');
      const failure2 = ServerFailure('Error 2', code: 'CODE');
      expect(failure1, isNot(equals(failure2)));
    });

    test('failures with different codes should not be equal', () {
      const failure1 = ServerFailure('Error', code: 'CODE1');
      const failure2 = ServerFailure('Error', code: 'CODE2');
      expect(failure1, isNot(equals(failure2)));
    });

    test('failures with null code should be equal', () {
      const failure1 = ServerFailure('Error');
      const failure2 = ServerFailure('Error');
      expect(failure1, equals(failure2));
    });

    test('different failure types should not be equal', () {
      const failure1 = ServerFailure('Error', code: 'CODE');
      const failure2 = NetworkFailure('Error', code: 'CODE');
      expect(failure1, isNot(equals(failure2)));
    });
  });

  group('Edge Cases', () {
    test('failures should handle empty message', () {
      const failure = ServerFailure('');
      expect(failure.message, isEmpty);
    });

    test('failures should handle long messages', () {
      final longMessage = 'A' * 1000;
      final failure = ServerFailure(longMessage);
      expect(failure.message.length, 1000);
    });

    test('all failure types should extend Failure', () {
      expect(const ServerFailure('Error'), isA<Failure>());
      expect(const NetworkFailure('Error'), isA<Failure>());
      expect(const CacheFailure('Error'), isA<Failure>());
      expect(const ValidationFailure('Error'), isA<Failure>());
      expect(const AuthFailure('Error'), isA<Failure>());
      expect(const PermissionFailure('Error'), isA<Failure>());
      expect(const UnknownFailure('Error'), isA<Failure>());
    });
  });
}

// Test implementation of Failure for testing
class TestFailure extends Failure {
  const TestFailure(super.message, {super.code});
}
