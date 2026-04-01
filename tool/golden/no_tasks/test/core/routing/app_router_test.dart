import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('goRouterProvider (no tasks)', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('should include login/register/home routes', () {
      container = ProviderContainer();
      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;

      expect(
        routes.any((r) => r is GoRoute && r.path == AppRoutes.login),
        isTrue,
      );
      expect(
        routes.any((r) => r is GoRoute && r.path == AppRoutes.register),
        isTrue,
      );
      expect(
        routes.any((r) => r is GoRoute && r.path == AppRoutes.home),
        isTrue,
      );
    });

    test('should not include tasks route', () {
      container = ProviderContainer();
      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;

      expect(routes.any((r) => r is GoRoute && r.path == '/tasks'), isFalse);
    });

    test('should redirect unauthenticated user to login', () {
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => AuthNotifier()..build()),
        ],
      );
      final router = container.read(goRouterProvider);
      expect(router.configuration.redirect, isNotNull);
    });

    test('should redirect authenticated user away from auth routes', () {
      const user = User(id: '1', email: 'test@example.com');
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => AuthNotifier()..state = const AuthState(user: user),
          ),
        ],
      );
      final router = container.read(goRouterProvider);
      expect(router.configuration.redirect, isNotNull);
    });
  });
}
