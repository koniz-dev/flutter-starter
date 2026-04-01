import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_starter/features/auth/routing/auth_routes.dart';
import 'package:flutter_starter/features/home/routing/home_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('buildAppRoutes', () {
    test('should include auth routes and home route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final appRoutesProvider = Provider<List<RouteBase>>(buildAppRoutes);
      final routes = container.read(appRoutesProvider);

      // Stripped baseline: auth routes first, then home.
      expect(routes.length, greaterThanOrEqualTo(3));

      final authRoutesProvider = Provider<List<RouteBase>>(buildAuthRoutes);
      final authRoutes = container.read(authRoutesProvider);
      expect(authRoutes, hasLength(2));

      // Validate that the first N routes match auth routes by shape.
      for (var i = 0; i < authRoutes.length; i++) {
        expect(routes[i], isA<GoRoute>());
        expect(authRoutes[i], isA<GoRoute>());
        expect((routes[i] as GoRoute).path, (authRoutes[i] as GoRoute).path);
        expect((routes[i] as GoRoute).name, (authRoutes[i] as GoRoute).name);
      }

      // Last route is home route (per routes_registry).
      final homeRouteProvider = Provider<GoRoute>(buildHomeRoute);
      final expectedHome = container.read(homeRouteProvider);
      final actualHome = routes.last as GoRoute;
      expect(actualHome.path, expectedHome.path);
      expect(actualHome.name, expectedHome.name);
    });
  });
}
