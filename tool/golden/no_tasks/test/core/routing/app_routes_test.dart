import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes', () {
    test('should have core route paths', () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.login, '/login');
      expect(AppRoutes.register, '/register');
    });

    test('should have feature flags debug route path', () {
      expect(AppRoutes.featureFlagsDebug, '/feature-flags-debug');
    });

    test('should have route names', () {
      expect(AppRoutes.homeName, 'home');
      expect(AppRoutes.loginName, 'login');
      expect(AppRoutes.registerName, 'register');
      expect(AppRoutes.featureFlagsDebugName, 'feature-flags-debug');
    });
  });
}
