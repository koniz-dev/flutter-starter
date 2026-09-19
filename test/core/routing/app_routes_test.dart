import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

// Only the routes every strip variant keeps are asserted here. The sample
// features assert their own constants in their own `routing/` tests, which
// `tool/strip_sample_features.dart` deletes along with the feature.

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

  group('RouteQueryParams', () {
    test('redirect key is the literal the auth guard round-trips', () {
      // `app_router.dart` writes this key onto /login and reads it back to
      // decide where to send the user after authenticating, so its value is
      // part of the URL contract, not an implementation detail.
      expect(RouteQueryParams.redirect, 'redirect');
    });
  });
}
