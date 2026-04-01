import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes', () {
    test('should have home route path', () {
      expect(AppRoutes.home, '/');
    });

    test('should have login route path', () {
      expect(AppRoutes.login, '/login');
    });

    test('should have register route path', () {
      expect(AppRoutes.register, '/register');
    });

    test('should have route names', () {
      expect(AppRoutes.homeName, 'home');
      expect(AppRoutes.loginName, 'login');
      expect(AppRoutes.registerName, 'register');
    });

    test('should have unique route paths', () {
      final paths = [AppRoutes.home, AppRoutes.login, AppRoutes.register];
      expect(paths.toSet().length, paths.length);
    });
  });

  group('RouteParams', () {
    test('should be accessible', () {
      expect(RouteParams, isNotNull);
    });
  });

  group('RouteQueryParams', () {
    test('should be accessible', () {
      expect(RouteQueryParams, isNotNull);
    });
  });
}
