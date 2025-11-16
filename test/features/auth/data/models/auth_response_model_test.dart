import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthResponseModel', () {
    test('should create AuthResponseModel with required fields', () {
      // Arrange
      const user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
      );
      const token = 'access-token-123';

      // Act
      const model = AuthResponseModel(
        user: user,
        token: token,
      );

      // Assert
      expect(model.user, user);
      expect(model.token, token);
      expect(model.refreshToken, isNull);
    });

    test('should create AuthResponseModel with all fields', () {
      // Arrange
      const user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
      );
      const token = 'access-token-123';
      const refreshToken = 'refresh-token-123';

      // Act
      const model = AuthResponseModel(
        user: user,
        token: token,
        refreshToken: refreshToken,
      );

      // Assert
      expect(model.user, user);
      expect(model.token, token);
      expect(model.refreshToken, refreshToken);
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        // Arrange
        const user = UserModel(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
        );
        const model = AuthResponseModel(
          user: user,
          token: 'access-token-123',
          refreshToken: 'refresh-token-123',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['token'], 'access-token-123');
        expect(json['refreshToken'], 'refresh-token-123');
        expect(json['user'], isA<Map<String, dynamic>>());
        final userJson = json['user'] as Map<String, dynamic>;
        expect(userJson['id'], 'user-123');
        expect(userJson['email'], 'test@example.com');
      });

      test('should serialize to JSON without refreshToken when null', () {
        // Arrange
        const user = UserModel(
          id: 'user-123',
          email: 'test@example.com',
        );
        const model = AuthResponseModel(
          user: user,
          token: 'access-token-123',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['token'], 'access-token-123');
        expect(json['refreshToken'], isNull);
        expect(json['user'], isA<Map<String, dynamic>>());
      });

      test('should deserialize from JSON correctly', () {
        // Arrange
        final json = <String, dynamic>{
          'user': {
            'id': 'user-123',
            'email': 'test@example.com',
            'name': 'Test User',
          },
          'token': 'access-token-123',
          'refreshToken': 'refresh-token-123',
        };

        // Act
        final model = AuthResponseModel.fromJson(json);

        // Assert
        expect(model.token, 'access-token-123');
        expect(model.refreshToken, 'refresh-token-123');
        expect(model.user.id, 'user-123');
        expect(model.user.email, 'test@example.com');
        expect(model.user.name, 'Test User');
      });

      test('should deserialize from JSON without refreshToken', () {
        // Arrange
        final json = <String, dynamic>{
          'user': {
            'id': 'user-123',
            'email': 'test@example.com',
          },
          'token': 'access-token-123',
        };

        // Act
        final model = AuthResponseModel.fromJson(json);

        // Assert
        expect(model.token, 'access-token-123');
        expect(model.refreshToken, isNull);
        expect(model.user.id, 'user-123');
        expect(model.user.email, 'test@example.com');
      });

      test('should handle nested user model serialization', () {
        // Arrange
        const user = UserModel(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          avatarUrl: 'https://example.com/avatar.jpg',
        );
        const model = AuthResponseModel(
          user: user,
          token: 'access-token-123',
        );

        // Act
        final json = model.toJson();

        // Assert
        expect(json['user'], isA<Map<String, dynamic>>());
        final userJson = json['user'] as Map<String, dynamic>;
        expect(userJson['id'], 'user-123');
        expect(userJson['email'], 'test@example.com');
        expect(userJson['name'], 'Test User');
        expect(userJson['avatar_url'], 'https://example.com/avatar.jpg');
      });
    });

    group('Equality', () {
      test('should be equal when all fields match', () {
        // Arrange
        const user = UserModel(
          id: 'user-123',
          email: 'test@example.com',
        );
        const model1 = AuthResponseModel(
          user: user,
          token: 'token-123',
          refreshToken: 'refresh-123',
        );
        const model2 = AuthResponseModel(
          user: user,
          token: 'token-123',
          refreshToken: 'refresh-123',
        );

        // Assert
        expect(model1.token, model2.token);
        expect(model1.refreshToken, model2.refreshToken);
        expect(model1.user.id, model2.user.id);
      });

      test('should not be equal when token differs', () {
        // Arrange
        const user = UserModel(
          id: 'user-123',
          email: 'test@example.com',
        );
        const model1 = AuthResponseModel(
          user: user,
          token: 'token-123',
        );
        const model2 = AuthResponseModel(
          user: user,
          token: 'token-456',
        );

        // Assert
        expect(model1.token, isNot(model2.token));
      });
    });
  });
}
