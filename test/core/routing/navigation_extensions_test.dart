import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/routing/route_not_found_screen.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

// These tests drive the *app's* router (`goRouterProvider`), not a router
// assembled in the test file. A local router can register whatever the helper
// under test happens to need, which is how `goToTasks()` read as covered for
// the year the app registered no `/tasks` route at all (#56). Pumping the real
// tree means a helper pointing at an unregistered location fails here.
//
// Every case states its auth precondition, because the top-level redirect is
// part of the behaviour: `sessionRestorationProvider` is overridden with a
// completed future so the guard is not sitting in its "restore in flight"
// hold state (#51), which is what `main()` has already awaited before
// `runApp`.

void main() {
  late ProviderContainer container;

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    required bool authenticated,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _TestAuthNotifier(
            authenticated
                ? const AuthState(
                    user: User(id: '1', email: 'test@example.com'),
                  )
                : const AuthState(),
          ),
        ),
        sessionRestorationProvider.overrideWith((ref) async {}),
      ],
    );
    addTearDown(container.dispose);

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

  // `GoRouter.state` is the state of the top-most match. Reading
  // `routeInformationProvider.value` or `currentConfiguration.uri` instead
  // would lag: an imperative `push` stacks its own match list on top without
  // moving either of those, so a pushed route still reports the location
  // underneath it.
  String locationOf(GoRouter router) => router.state.uri.toString();

  /// Context of the top-most screen, which is what a user's tap would carry.
  BuildContext topContext(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  group('NavigationExtensions destinations', () {
    testWidgets('goToHome navigates an authenticated user to home', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: true);
      router.go('/definitely-not-a-route');
      await tester.pumpAndSettle();
      expect(find.byType(RouteNotFoundScreen), findsOneWidget);

      topContext(tester).goToHome();
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('goToLogin navigates an unauthenticated user to login', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);
      router.go(AppRoutes.register);
      await tester.pumpAndSettle();

      topContext(tester).goToLogin();
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('goToRegister navigates an unauthenticated user to register', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);

      topContext(tester).goToRegister();
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.register);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  group('NavigationExtensions push and replace', () {
    testWidgets('pushRoute stacks the new route on the current one', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);

      topContext(tester).pushRoute(AppRoutes.register);
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.register);
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(router.canPop(), isTrue);
    });

    testWidgets('pushRoute carries extra through to the pushed route', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);

      topContext(tester).pushRoute(
        AppRoutes.register,
        extra: const {'key': 'value'},
      );
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.register);
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(GoRouterState.of(topContext(tester)).extra, const {
        'key': 'value',
      });
    });

    testWidgets('pushNamedRoute resolves the route name', (tester) async {
      final router = await pumpRouter(tester, authenticated: false);

      topContext(tester).pushNamedRoute(AppRoutes.registerName);
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.register);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('pushNamedRoute appends query parameters', (tester) async {
      final router = await pumpRouter(tester, authenticated: false);

      topContext(tester).pushNamedRoute(
        AppRoutes.registerName,
        queryParameters: {'filter': 'active'},
      );
      await tester.pumpAndSettle();

      expect(locationOf(router), '${AppRoutes.register}?filter=active');
      expect(
        GoRouterState.of(topContext(tester)).uri.queryParameters['filter'],
        'active',
      );
    });

    testWidgets('replaceRoute swaps the top route without growing the stack', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);
      topContext(tester).pushRoute(AppRoutes.register);
      await tester.pumpAndSettle();

      topContext(tester).replaceRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.login);
      expect(find.byType(RegisterScreen), findsNothing);
      // Still one entry deep: replace swapped the top, it did not push.
      expect(router.canPop(), isTrue);
      topContext(tester).popRoute<void>();
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
    });

    testWidgets('replaceNamedRoute swaps the top route by name', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);
      topContext(tester).pushRoute(AppRoutes.register);
      await tester.pumpAndSettle();

      topContext(tester).replaceNamedRoute(AppRoutes.loginName);
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.login);
      expect(find.byType(RegisterScreen), findsNothing);
    });
  });

  group('NavigationExtensions pop', () {
    testWidgets('popRoute returns to the previous route', (tester) async {
      final router = await pumpRouter(tester, authenticated: false);
      topContext(tester).pushRoute(AppRoutes.register);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      topContext(tester).popRoute<void>();
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.login);
      expect(find.byType(RegisterScreen), findsNothing);
      expect(router.canPop(), isFalse);
    });

    testWidgets('popRoute hands the result back to the pusher', (tester) async {
      final router = await pumpRouter(tester, authenticated: false);
      final pushed = router.push<String>(AppRoutes.register);
      await tester.pumpAndSettle();

      topContext(tester).popRoute<String>('result');
      await tester.pumpAndSettle();

      expect(await pushed, 'result');
      expect(locationOf(router), AppRoutes.login);
    });

    testWidgets(
      'popUntilRoute stops at the target instead of emptying the stack',
      (tester) async {
        final router = await pumpRouter(tester, authenticated: false);
        // /login -> /register -> /login. Three deep is the minimum that tells
        // a correct implementation apart from one that pops until it cannot:
        // at two deep both land in the same place.
        topContext(tester).pushRoute(AppRoutes.register);
        await tester.pumpAndSettle();
        topContext(tester).pushRoute(AppRoutes.login);
        await tester.pumpAndSettle();
        expect(locationOf(router), AppRoutes.login);

        topContext(tester).popUntilRoute(AppRoutes.register);
        await tester.pumpAndSettle();

        expect(locationOf(router), AppRoutes.register);
        expect(find.byType(RegisterScreen), findsOneWidget);
        // The bottom /login entry is still there - the stack was not emptied.
        expect(router.canPop(), isTrue);
      },
    );

    testWidgets('popUntilRoute pops nothing when already on the target', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);
      topContext(tester).pushRoute(AppRoutes.register);
      await tester.pumpAndSettle();

      topContext(tester).popUntilRoute(AppRoutes.register);
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.register);
      expect(router.canPop(), isTrue);
    });

    testWidgets('canPopRoute reports true once a route is pushed', (
      tester,
    ) async {
      await pumpRouter(tester, authenticated: false);
      topContext(tester).pushRoute(AppRoutes.register);
      await tester.pumpAndSettle();

      expect(topContext(tester).canPopRoute(), isTrue);
    });

    testWidgets('canPopRoute reports false at the bottom of the stack', (
      tester,
    ) async {
      await pumpRouter(tester, authenticated: false);

      expect(topContext(tester).canPopRoute(), isFalse);
    });

    testWidgets('popOrGoToHome pops when there is something to pop', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: false);
      topContext(tester).pushRoute(AppRoutes.register);
      await tester.pumpAndSettle();

      topContext(tester).popOrGoToHome();
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('popOrGoToHome goes home when the stack is empty', (
      tester,
    ) async {
      final router = await pumpRouter(tester, authenticated: true);
      router.go('/definitely-not-a-route');
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);

      topContext(tester).popOrGoToHome();
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
