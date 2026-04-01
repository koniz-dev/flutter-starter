import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/home/routing/home_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('buildHomeRoute', () {
    test('should build home route with correct path and name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final homeRouteProvider = Provider<GoRoute>(buildHomeRoute);
      final route = container.read(homeRouteProvider);

      expect(route.path, AppRoutes.home);
      expect(route.name, AppRoutes.homeName);
      expect(route.routes, isEmpty);
    });

    test('should attach provided children routes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final child = GoRoute(
        path: 'child',
        builder: (_, _) => const SizedBox(),
      );
      final homeRouteWithChildrenProvider = Provider<GoRoute>((ref) {
        return buildHomeRoute(ref, children: <RouteBase>[child]);
      });
      final route = container.read(homeRouteWithChildrenProvider);

      expect(route.routes, hasLength(1));
      expect(route.routes.first, same(child));
    });
  });
}
