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

      // The registry's contract is membership, not order: go_router
      // matches top-level routes by path, so a feature module may sit
      // anywhere in the list, after home included. Feature modules assert
      // their own registration in test/features/<feature>/routing/.
      String key(RouteBase route) => '${(route as GoRoute).name} ${route.path}';
      final registered = {for (final route in routes) key(route)};

      final authRoutesProvider = Provider<List<RouteBase>>(buildAuthRoutes);
      final authRoutes = container.read(authRoutesProvider);
      expect(authRoutes, hasLength(2));
      final homeRouteProvider = Provider<GoRoute>(buildHomeRoute);
      final home = container.read(homeRouteProvider);

      expect(registered, containsAll([...authRoutes.map(key), key(home)]));
    });
  });
}
