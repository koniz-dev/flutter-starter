import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/routing/auth_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('buildAuthRoutes', () {
    test('should build login and register routes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final routesProvider = Provider<List<RouteBase>>(buildAuthRoutes);
      final routes = container.read(routesProvider);

      expect(routes, hasLength(2));
      expect(routes.every((r) => r is GoRoute), isTrue);

      final login =
          routes.firstWhere(
                (r) => r is GoRoute && r.path == AppRoutes.login,
                orElse: () => throw StateError('Login route not found'),
              )
              as GoRoute;
      expect(login.name, AppRoutes.loginName);

      final register =
          routes.firstWhere(
                (r) => r is GoRoute && r.path == AppRoutes.register,
                orElse: () => throw StateError('Register route not found'),
              )
              as GoRoute;
      expect(register.name, AppRoutes.registerName);
    });
  });
}
