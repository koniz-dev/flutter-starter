import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/route_not_found_screen.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
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

// Since #51 the guard holds the requested location while
// `sessionRestorationProvider` is loading instead of bouncing to `/login` -
// otherwise every returning user flashes the login screen. A widget test with
// no mock storage channel never settles the real restore
// (`SharedPreferences.getInstance()` never answers under the test binding), so
// the tests below that boot unauthenticated say "restore finished and found
// nothing" explicitly, which is what `main()` has already awaited by the time
// it calls `runApp`.

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
      container = ProviderContainer();

      final router = container.read(goRouterProvider);

      expect(router, isA<GoRouter>());
    });

    test('should start on the home location', () {
      container = ProviderContainer();

      final router = container.read(goRouterProvider);

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
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
          sessionRestorationProvider.overrideWith((ref) async {}),
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
          sessionRestorationProvider.overrideWith((ref) async {}),
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

    test('should expose the redirect the auth guard is built from', () {
      container = ProviderContainer();

      final router = container.read(goRouterProvider);

      // The guard's behaviour is asserted by the widget tests below; this
      // only pins that a redirect is wired at all, so deleting it from
      // `app_router.dart` fails here rather than silently opening the app.
      expect(router.configuration.topRedirect, isNotNull);
    });
  });

  group('errorBuilder', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    Future<GoRouter> pumpAuthenticated(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _TestAuthNotifier(
              const AuthState(
                user: User(id: '1', email: 'test@example.com'),
              ),
            ),
          ),
          sessionRestorationProvider.overrideWith((ref) async {}),
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
      return router;
    }

    testWidgets(
      'renders the product 404 for an unmatched path, not go_router debug',
      (tester) async {
        final router = await pumpAuthenticated(tester);

        router.go('/no-such-page');
        await tester.pumpAndSettle();

        expect(find.byType(RouteNotFoundScreen), findsOneWidget);
        // Wording, not just pixels: a golden cannot show this (Ahem renders
        // every glyph as a block), and go_router's own error page would show
        // the raw exception text instead.
        expect(find.text('Page not found'), findsNWidgets(2));
        expect(
          find.text('The page you are looking for does not exist.'),
          findsOneWidget,
        );
        expect(find.text('/no-such-page'), findsOneWidget);
        expect(find.byType(ErrorWidget), findsNothing);
      },
    );

    testWidgets('the 404 offers a way back to home', (tester) async {
      final router = await pumpAuthenticated(tester);

      router.go('/no-such-page');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to home'));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('_AuthStateNotifier', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    testWidgets('re-runs the redirect when the user logs out', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _TestAuthNotifier(
              const AuthState(
                user: User(id: '1', email: 'test@example.com'),
              ),
            ),
          ),
          sessionRestorationProvider.overrideWith((ref) async {}),
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
      expect(router.state.uri.path, AppRoutes.home);

      // Dropping the user must move the router without anyone calling go().
      container.read(authNotifierProvider.notifier).state = const AuthState();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.login);
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

    test('every registered top-level path is unique', () {
      container = ProviderContainer();

      final router = container.read(goRouterProvider);
      final paths = router.configuration.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();

      expect(paths, isNotEmpty);
      expect(paths.toSet(), hasLength(paths.length));
    });
  });

  group('Edge Cases', () {
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    test('router creation reflects the auth state it was built with', () {
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _TestAuthNotifier(const AuthState()),
          ),
        ],
      );
      final unauthenticated = container.read(goRouterProvider);
      expect(unauthenticated.configuration.routes, isNotEmpty);

      container.dispose();

      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _TestAuthNotifier(
              const AuthState(
                user: User(id: '1', email: 'test@example.com'),
              ),
            ),
          ),
        ],
      );
      final authenticated = container.read(goRouterProvider);

      expect(
        authenticated.configuration.routes.length,
        unauthenticated.configuration.routes.length,
      );
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
