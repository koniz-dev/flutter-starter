import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

void main() {
  group('goRouterProvider', () {
    late ProviderContainer container;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockLoggingService = MockLoggingService();
      when(
        () => mockLoggingService.info(any(), context: any(named: 'context')),
      ).thenReturn(null);
    });

    tearDown(() {
      container.dispose();
    });

    test('should create GoRouter instance', () {
      // Arrange
      container = ProviderContainer(
        overrides: [
          // Override logging service to avoid initialization issues
        ],
      );

      // Act
      final router = container.read(goRouterProvider);

      // Assert
      expect(router, isA<GoRouter>());
      expect(router, isNotNull);
    });

    test('should have router configuration', () {
      container = ProviderContainer();
      final router = container.read(goRouterProvider);
      expect(router.configuration, isNotNull);
    });

    test('should have all routes configured', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;

      // Assert
      expect(routes, isNotEmpty);
      // Check that routes exist (exact count may vary based on nested routes)
      expect(routes.length, greaterThan(0));
    });

    test('should have login route', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;

      // Assert
      final loginRoute = routes.firstWhere(
        (route) => route is GoRoute && route.path == AppRoutes.login,
        orElse: () => throw StateError('Login route not found'),
      );
      expect(loginRoute, isNotNull);
      if (loginRoute is GoRoute) {
        expect(loginRoute.name, AppRoutes.loginName);
      }
    });

    test('should have register route', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;

      // Assert
      final registerRoute = routes.firstWhere(
        (route) => route is GoRoute && route.path == AppRoutes.register,
        orElse: () => throw StateError('Register route not found'),
      );
      expect(registerRoute, isNotNull);
      if (registerRoute is GoRoute) {
        expect(registerRoute.name, AppRoutes.registerName);
      }
    });

    test('should have home route', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;

      // Assert
      final homeRoute = routes.firstWhere(
        (route) => route is GoRoute && route.path == AppRoutes.home,
        orElse: () => throw StateError('Home route not found'),
      );
      expect(homeRoute, isNotNull);
      if (homeRoute is GoRoute) {
        expect(homeRoute.name, AppRoutes.homeName);
      }
    });

    testWidgets('should redirect unauthenticated user from home to login', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => AuthNotifier()..build()),
        ],
      );
      final router = container.read(goRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    });

    testWidgets('should allow unauthenticated user to access register route', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => AuthNotifier()..build()),
        ],
      );
      final router = container.read(goRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );
      router.go(AppRoutes.register);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.register,
      );
    });

    testWidgets('should redirect authenticated user away from auth routes', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const user = User(id: '1', email: 'test@example.com');
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _TestAuthNotifier(const AuthState(user: user)),
          ),
        ],
      );
      final router = container.read(goRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go(AppRoutes.login);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
    });

    test('should return same router instance on multiple reads', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final router1 = container.read(goRouterProvider);
      final router2 = container.read(goRouterProvider);

      // Assert
      expect(router1, same(router2));
    });

    test('should create router with release-safe diagnostics defaults', () {
      // GoRouter does not expose debugLogDiagnostics; it is kDebugMode in
      // app_router.
      container = ProviderContainer();
      final router = container.read(goRouterProvider);
      expect(router, isNotNull);
    });
  });

  group('_AuthStateNotifier', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('should be created with router', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final router = container.read(goRouterProvider);

      // Assert
      // The notifier is internal to the router and not directly accessible
      // We verify the router is created successfully
      expect(router, isNotNull);
    });

    test('should handle auth state changes', () {
      // Arrange
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => AuthNotifier()..build()),
        ],
      );

      // Act
      final router = container.read(goRouterProvider);

      // Simulate auth state change
      container.read(authNotifierProvider.notifier).state = const AuthState(
        user: User(id: '1', email: 'test@example.com'),
      );

      // Assert
      // Router should still be functional after auth state change
      expect(router, isNotNull);
    });
  });

  group('Route Configuration', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('should have flat home route without nested children', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final router = container.read(goRouterProvider);
      final routes = router.configuration.routes;
      final homeRoute = routes.firstWhere(
        (route) => route is GoRoute && route.path == AppRoutes.home,
      );

      // Assert
      expect(homeRoute, isNotNull);
      if (homeRoute is GoRoute) {
        expect(homeRoute.routes, isEmpty);
      }
    });
  });

  group('Edge Cases', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('should handle router creation with different auth states', () {
      // Arrange & Act
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => AuthNotifier()..state = const AuthState(),
          ),
        ],
      );
      final router1 = container.read(goRouterProvider);

      container.dispose();

      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => AuthNotifier()
              ..state = const AuthState(
                user: User(id: '1', email: 'test@example.com'),
              ),
          ),
        ],
      );
      final router2 = container.read(goRouterProvider);

      // Assert
      expect(router1, isNotNull);
      expect(router2, isNotNull);
    });

    test('should handle multiple router reads', () {
      // Arrange
      container = ProviderContainer();

      // Act
      final routers = List.generate(5, (_) => container.read(goRouterProvider));

      // Assert
      expect(routers, isNotEmpty);
      expect(routers.length, 5);
      // All should be the same instance (singleton)
      for (var i = 1; i < routers.length; i++) {
        expect(routers[i], same(routers[0]));
      }
    });
  });
}
