import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('goRouterProvider (no feature flags)', () {
    test('should include tasks route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;

      expect(
        routes.any((r) => r is GoRoute && r.path == AppRoutes.tasks),
        isTrue,
      );
    });

    test('should not include feature flags debug route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;
      final homeRoute =
          routes.firstWhere((r) => r is GoRoute && r.path == AppRoutes.home)
              as GoRoute;

      expect(
        homeRoute.routes.any(
          (r) => r is GoRoute && r.path == 'feature-flags-debug',
        ),
        isFalse,
      );
    });
  });
}
