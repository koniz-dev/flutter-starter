import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiEndpoints', () {
    test('should have apiVersion constant', () {
      expect(ApiEndpoints.apiVersion, isA<String>());
      expect(ApiEndpoints.apiVersion, '/v1');
      expect(ApiEndpoints.apiVersion, startsWith('/'));
    });

    test('should have login endpoint', () {
      expect(ApiEndpoints.login, isA<String>());
      expect(ApiEndpoints.login, '/auth/login');
      expect(ApiEndpoints.login, startsWith('/'));
    });

    test('should have register endpoint', () {
      expect(ApiEndpoints.register, isA<String>());
      expect(ApiEndpoints.register, '/auth/register');
      expect(ApiEndpoints.register, startsWith('/'));
    });

    test('should have logout endpoint', () {
      expect(ApiEndpoints.logout, isA<String>());
      expect(ApiEndpoints.logout, '/auth/logout');
      expect(ApiEndpoints.logout, startsWith('/'));
    });

    test('should have refreshToken endpoint', () {
      expect(ApiEndpoints.refreshToken, isA<String>());
      expect(ApiEndpoints.refreshToken, '/auth/refresh');
      expect(ApiEndpoints.refreshToken, startsWith('/'));
    });

    test('should have userProfile endpoint', () {
      expect(ApiEndpoints.userProfile, isA<String>());
      expect(ApiEndpoints.userProfile, '/user/profile');
      expect(ApiEndpoints.userProfile, startsWith('/'));
    });

    test('should have updateProfile endpoint', () {
      expect(ApiEndpoints.updateProfile, isA<String>());
      expect(ApiEndpoints.updateProfile, '/user/profile');
      expect(ApiEndpoints.updateProfile, startsWith('/'));
    });

    test('should have all endpoints starting with /', () {
      expect(ApiEndpoints.apiVersion, startsWith('/'));
      expect(ApiEndpoints.login, startsWith('/'));
      expect(ApiEndpoints.register, startsWith('/'));
      expect(ApiEndpoints.logout, startsWith('/'));
      expect(ApiEndpoints.refreshToken, startsWith('/'));
      expect(ApiEndpoints.userProfile, startsWith('/'));
      expect(ApiEndpoints.updateProfile, startsWith('/'));
    });

    test('should have auth endpoints under /auth path', () {
      expect(ApiEndpoints.login, contains('/auth/'));
      expect(ApiEndpoints.register, contains('/auth/'));
      expect(ApiEndpoints.logout, contains('/auth/'));
      expect(ApiEndpoints.refreshToken, contains('/auth/'));
    });

    test('should have user endpoints under /user path', () {
      expect(ApiEndpoints.userProfile, contains('/user/'));
      expect(ApiEndpoints.updateProfile, contains('/user/'));
    });
  });
}
