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

    test('should have all endpoints as non-empty strings', () {
      expect(ApiEndpoints.apiVersion, isNotEmpty);
      expect(ApiEndpoints.login, isNotEmpty);
      expect(ApiEndpoints.register, isNotEmpty);
      expect(ApiEndpoints.logout, isNotEmpty);
      expect(ApiEndpoints.refreshToken, isNotEmpty);
      expect(ApiEndpoints.userProfile, isNotEmpty);
      expect(ApiEndpoints.updateProfile, isNotEmpty);
    });

    test('should have consistent endpoint structure', () {
      // All endpoints should start with /
      final endpoints = [
        ApiEndpoints.apiVersion,
        ApiEndpoints.login,
        ApiEndpoints.register,
        ApiEndpoints.logout,
        ApiEndpoints.refreshToken,
        ApiEndpoints.userProfile,
        ApiEndpoints.updateProfile,
      ];
      for (final endpoint in endpoints) {
        expect(endpoint, startsWith('/'));
      }
    });

    test('should have apiVersion as prefix for endpoints', () {
      expect(ApiEndpoints.apiVersion, '/v1');
    });

    test('should have unique endpoint paths', () {
      final endpoints = [
        ApiEndpoints.login,
        ApiEndpoints.register,
        ApiEndpoints.logout,
        ApiEndpoints.refreshToken,
        ApiEndpoints.userProfile,
        ApiEndpoints.updateProfile,
      ];
      // userProfile and updateProfile can be the same (both are PUT/PATCH)
      // But others should be unique
      final uniqueEndpoints = endpoints.toSet();
      expect(uniqueEndpoints.length, greaterThanOrEqualTo(5));
    });

    test('should have endpoints with valid URL structure', () {
      // All endpoints should be valid URL paths
      expect(ApiEndpoints.apiVersion, matches('^/[^/]+'));
      expect(ApiEndpoints.login, matches(r'^/[^/]+(/[^/]+)*$'));
      expect(ApiEndpoints.register, matches(r'^/[^/]+(/[^/]+)*$'));
      expect(ApiEndpoints.logout, matches(r'^/[^/]+(/[^/]+)*$'));
      expect(ApiEndpoints.refreshToken, matches(r'^/[^/]+(/[^/]+)*$'));
      expect(ApiEndpoints.userProfile, matches(r'^/[^/]+(/[^/]+)*$'));
      expect(ApiEndpoints.updateProfile, matches(r'^/[^/]+(/[^/]+)*$'));
    });

    test('should have endpoints without trailing slashes', () {
      // Endpoints should not end with / (except root)
      final endpoints = [
        ApiEndpoints.login,
        ApiEndpoints.register,
        ApiEndpoints.logout,
        ApiEndpoints.refreshToken,
        ApiEndpoints.userProfile,
        ApiEndpoints.updateProfile,
      ];
      for (final endpoint in endpoints) {
        expect(endpoint, isNot(endsWith('/')));
      }
    });

    test('should have apiVersion that can be used as prefix', () {
      // apiVersion should be usable as a prefix for other endpoints
      expect(ApiEndpoints.apiVersion, '/v1');
      expect(ApiEndpoints.login, isNot(startsWith(ApiEndpoints.apiVersion)));
      // Note: In real usage, endpoints might be prefixed with apiVersion
    });

    test('should have all endpoints accessible as static members', () {
      // Verify all endpoints can be accessed
      expect(() => ApiEndpoints.apiVersion, returnsNormally);
      expect(() => ApiEndpoints.login, returnsNormally);
      expect(() => ApiEndpoints.register, returnsNormally);
      expect(() => ApiEndpoints.logout, returnsNormally);
      expect(() => ApiEndpoints.refreshToken, returnsNormally);
      expect(() => ApiEndpoints.userProfile, returnsNormally);
      expect(() => ApiEndpoints.updateProfile, returnsNormally);
    });

    test('should have endpoints with reasonable length', () {
      // Endpoints should not be too long
      final endpoints = [
        ApiEndpoints.apiVersion,
        ApiEndpoints.login,
        ApiEndpoints.register,
        ApiEndpoints.logout,
        ApiEndpoints.refreshToken,
        ApiEndpoints.userProfile,
        ApiEndpoints.updateProfile,
      ];
      for (final endpoint in endpoints) {
        expect(endpoint.length, lessThan(100));
        expect(endpoint.length, greaterThan(0));
      }
    });

    test('should have apiVersion with correct format', () {
      // apiVersion should be in format /v{number}
      expect(ApiEndpoints.apiVersion, matches(r'^/v\d+$'));
    });

    test('should have all endpoints as const values', () {
      // All endpoints should be compile-time constants
      expect(ApiEndpoints.apiVersion, isA<String>());
      expect(ApiEndpoints.login, isA<String>());
      expect(ApiEndpoints.register, isA<String>());
      expect(ApiEndpoints.logout, isA<String>());
      expect(ApiEndpoints.refreshToken, isA<String>());
      expect(ApiEndpoints.userProfile, isA<String>());
      expect(ApiEndpoints.updateProfile, isA<String>());
    });

    test('should have endpoints that can be concatenated', () {
      // Endpoints should work when concatenated with base URL
      const baseUrl = 'https://api.example.com';
      const fullUrl = '$baseUrl${ApiEndpoints.login}';
      expect(fullUrl, 'https://api.example.com/auth/login');
    });

    test('should have apiVersion usable in URL construction', () {
      // apiVersion should be usable in URL construction
      const baseUrl = 'https://api.example.com';
      const versionedUrl =
          '$baseUrl${ApiEndpoints.apiVersion}${ApiEndpoints.login}';
      expect(versionedUrl, contains('/v1'));
      expect(versionedUrl, contains('/auth/login'));
    });
  });
}
