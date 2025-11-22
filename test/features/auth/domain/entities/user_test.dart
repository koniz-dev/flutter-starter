import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User', () {
    test('should create user with required fields', () {
      // Arrange & Act
      const user = User(
        id: '1',
        email: 'test@example.com',
      );

      // Assert
      expect(user.id, '1');
      expect(user.email, 'test@example.com');
      expect(user.name, isNull);
      expect(user.avatarUrl, isNull);
    });

    test('should create user with all fields', () {
      // Arrange & Act
      const user = User(
        id: '1',
        email: 'test@example.com',
        name: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      // Assert
      expect(user.id, '1');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('should create user with only name', () {
      // Arrange & Act
      const user = User(
        id: '1',
        email: 'test@example.com',
        name: 'Test User',
      );

      // Assert
      expect(user.id, '1');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.avatarUrl, isNull);
    });

    test('should create user with only avatarUrl', () {
      // Arrange & Act
      const user = User(
        id: '1',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      // Assert
      expect(user.id, '1');
      expect(user.email, 'test@example.com');
      expect(user.name, isNull);
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    });

    group('equality', () {
      test('should be equal when id and email are same', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test@example.com',
          name: 'User 1',
        );
        const user2 = User(
          id: '1',
          email: 'test@example.com',
          name: 'User 2',
        );

        // Act & Assert
        expect(user1, user2);
        expect(user1 == user2, isTrue);
      });

      test('should not be equal when id is different', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test@example.com',
        );
        const user2 = User(
          id: '2',
          email: 'test@example.com',
        );

        // Act & Assert
        expect(user1, isNot(user2));
        expect(user1 == user2, isFalse);
      });

      test('should not be equal when email is different', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test1@example.com',
        );
        const user2 = User(
          id: '1',
          email: 'test2@example.com',
        );

        // Act & Assert
        expect(user1, isNot(user2));
        expect(user1 == user2, isFalse);
      });

      test('should not be equal when both id and email are different', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test1@example.com',
        );
        const user2 = User(
          id: '2',
          email: 'test2@example.com',
        );

        // Act & Assert
        expect(user1, isNot(user2));
        expect(user1 == user2, isFalse);
      });

      test('should be equal to itself', () {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
        );

        // Act & Assert
        expect(user, user);
        expect(user == user, isTrue);
      });

      test('should not be equal to null', () {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
        );

        // Act & Assert
        expect(user, isNot(null));
      });

      test('should not be equal to different type', () {
        // Arrange
        const user = User(
          id: '1',
          email: 'test@example.com',
        );

        // Act & Assert
        // User should not equal objects of different types
        expect(user, isNot('string'));
        expect(user, isNot(123));
        expect(user, isNot(<String, dynamic>{}));
      });

      test('should ignore name and avatarUrl in equality', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test@example.com',
          name: 'Name 1',
          avatarUrl: 'url1',
        );
        const user2 = User(
          id: '1',
          email: 'test@example.com',
          name: 'Name 2',
          avatarUrl: 'url2',
        );

        // Act & Assert
        expect(user1, user2);
        expect(user1 == user2, isTrue);
      });
    });

    group('hashCode', () {
      test('should have same hashCode for equal users', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test@example.com',
          name: 'User 1',
        );
        const user2 = User(
          id: '1',
          email: 'test@example.com',
          name: 'User 2',
        );

        // Act & Assert
        expect(user1.hashCode, user2.hashCode);
      });

      test('should have different hashCode for different ids', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test@example.com',
        );
        const user2 = User(
          id: '2',
          email: 'test@example.com',
        );

        // Act & Assert
        expect(user1.hashCode, isNot(user2.hashCode));
      });

      test('should have different hashCode for different emails', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test1@example.com',
        );
        const user2 = User(
          id: '1',
          email: 'test2@example.com',
        );

        // Act & Assert
        expect(user1.hashCode, isNot(user2.hashCode));
      });

      test('should have same hashCode when name/avatarUrl differ', () {
        // Arrange
        const user1 = User(
          id: '1',
          email: 'test@example.com',
          name: 'Name 1',
          avatarUrl: 'url1',
        );
        const user2 = User(
          id: '1',
          email: 'test@example.com',
          name: 'Name 2',
          avatarUrl: 'url2',
        );

        // Act & Assert
        expect(user1.hashCode, user2.hashCode);
      });
    });

    group('edge cases', () {
      test('should handle empty id', () {
        // Arrange & Act
        const user = User(
          id: '',
          email: 'test@example.com',
        );

        // Assert
        expect(user.id, isEmpty);
        expect(user.email, 'test@example.com');
      });

      test('should handle empty email', () {
        // Arrange & Act
        const user = User(
          id: '1',
          email: '',
        );

        // Assert
        expect(user.id, '1');
        expect(user.email, isEmpty);
      });

      test('should handle empty name', () {
        // Arrange & Act
        const user = User(
          id: '1',
          email: 'test@example.com',
          name: '',
        );

        // Assert
        expect(user.id, '1');
        expect(user.email, 'test@example.com');
        expect(user.name, isEmpty);
      });

      test('should handle empty avatarUrl', () {
        // Arrange & Act
        const user = User(
          id: '1',
          email: 'test@example.com',
          avatarUrl: '',
        );

        // Assert
        expect(user.id, '1');
        expect(user.email, 'test@example.com');
        expect(user.avatarUrl, isEmpty);
      });

      test('should handle long id', () {
        // Arrange
        final longId = 'a' * 1000;

        // Act
        final user = User(
          id: longId,
          email: 'test@example.com',
        );

        // Assert
        expect(user.id.length, 1000);
        expect(user.id, longId);
      });

      test('should handle long email', () {
        // Arrange
        final longEmail = 'a' * 1000 + '@example.com';

        // Act
        final user = User(
          id: '1',
          email: longEmail,
        );

        // Assert
        expect(user.email.length, greaterThan(1000));
        expect(user.email, longEmail);
      });

      test('should handle special characters in id', () {
        // Arrange & Act
        const user = User(
          id: 'user-123_abc.xyz',
          email: 'test@example.com',
        );

        // Assert
        expect(user.id, 'user-123_abc.xyz');
      });

      test('should handle special characters in email', () {
        // Arrange & Act
        const user = User(
          id: '1',
          email: 'test+tag@example.co.uk',
        );

        // Assert
        expect(user.email, 'test+tag@example.co.uk');
      });
    });

    group('immutability', () {
      test('should be immutable (const constructor)', () {
        // Arrange & Act
        const user = User(
          id: '1',
          email: 'test@example.com',
        );

        // Assert
        expect(user, isA<User>());
        // Can't modify fields as they are final
      });

      test('should allow const instances in collections', () {
        // Arrange
        const users = [
          User(id: '1', email: 'user1@example.com'),
          User(id: '2', email: 'user2@example.com'),
          User(id: '3', email: 'user3@example.com'),
        ];

        // Act & Assert
        expect(users.length, 3);
        expect(users[0].id, '1');
        expect(users[1].id, '2');
        expect(users[2].id, '3');
      });
    });
  });
}
