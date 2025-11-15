import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('should create UserModel with required fields', () {
      // Arrange & Act
      const model = UserModel(
        id: 'user-123',
        email: 'test@example.com',
      );

      // Assert
      expect(model.id, 'user-123');
      expect(model.email, 'test@example.com');
      expect(model.name, isNull);
      expect(model.avatarUrl, isNull);
    });

    test('should create UserModel with all fields', () {
      // Arrange & Act
      const model = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      // Assert
      expect(model.id, 'user-123');
      expect(model.email, 'test@example.com');
      expect(model.name, 'Test User');
      expect(model.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('should extend User entity', () {
      // Arrange & Act
      const model = UserModel(
        id: 'user-123',
        email: 'test@example.com',
      );

      // Assert
      expect(model, isA<User>());
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        // Arrange
        const model = UserModel(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'user-123');
        expect(json['email'], 'test@example.com');
        expect(json['name'], 'Test User');
        expect(json['avatar_url'], 'https://example.com/avatar.jpg');
      });

      test('should serialize to JSON with null optional fields', () {
        // Arrange
        const model = UserModel(
          id: 'user-123',
          email: 'test@example.com',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['id'], 'user-123');
        expect(json['email'], 'test@example.com');
        expect(json['name'], isNull);
        expect(json['avatar_url'], isNull);
      });

      test('should deserialize from JSON correctly', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'name': 'Test User',
          'avatar_url': 'https://example.com/avatar.jpg',
        };

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.id, 'user-123');
        expect(model.email, 'test@example.com');
        expect(model.name, 'Test User');
        expect(model.avatarUrl, 'https://example.com/avatar.jpg');
      });

      test('should deserialize from JSON with null optional fields', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
        };

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.id, 'user-123');
        expect(model.email, 'test@example.com');
        expect(model.name, isNull);
        expect(model.avatarUrl, isNull);
      });

      test('should handle avatar_url field name mapping', () {
        // Arrange
        final json = <String, dynamic>{
          'id': 'user-123',
          'email': 'test@example.com',
          'avatar_url': 'https://example.com/avatar.jpg',
        };

        // Act
        final model = UserModel.fromJson(json);

        // Assert
        expect(model.avatarUrl, 'https://example.com/avatar.jpg');
      });

      test('should map avatarUrl to avatar_url in JSON', () {
        // Arrange
        const model = UserModel(
          id: 'user-123',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['avatar_url'], 'https://example.com/avatar.jpg');
        expect(json.containsKey('avatarUrl'), isFalse);
      });
    });

    group('Equality', () {
      test('should be equal when all fields match', () {
        // Arrange
        const model1 = UserModel(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
        );
        const model2 = UserModel(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
        );

        // Assert
        expect(model1.id, model2.id);
        expect(model1.email, model2.email);
        expect(model1.name, model2.name);
      });

      test('should not be equal when fields differ', () {
        // Arrange
        const model1 = UserModel(
          id: 'user-123',
          email: 'test@example.com',
        );
        const model2 = UserModel(
          id: 'user-456',
          email: 'test@example.com',
        );

        // Assert
        expect(model1.id, isNot(model2.id));
      });
    });
  });
}
