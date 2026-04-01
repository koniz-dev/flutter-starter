import 'package:flutter/material.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('NavigationExtensions', () {
    Widget createTestWidget(Widget child) {
      return MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: AppRoutes.login,
              name: 'login',
              builder: (context, state) => const Scaffold(body: Text('Login')),
            ),
            GoRoute(
              path: AppRoutes.register,
              name: 'register',
              builder: (context, state) =>
                  const Scaffold(body: Text('Register')),
            ),
            GoRoute(
              path: AppRoutes.featureFlagsDebug,
              name: AppRoutes.featureFlagsDebugName,
              builder: (context, state) =>
                  const Scaffold(body: Text('FeatureFlags')),
            ),
            GoRoute(
              path: '/demo/:demoId',
              name: 'demo-detail',
              builder: (context, state) => Scaffold(
                body: Text('Demo ${state.pathParameters['demoId']}'),
              ),
            ),
          ],
        ),
        builder: (context, child) {
          return child!;
        },
      );
    }

    testWidgets('goToHome should navigate to home route', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester.element(find.byType(Scaffold)).goToHome();

      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('goToLogin should navigate to login route', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester.element(find.byType(Scaffold)).goToLogin();

      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('goToRegister should navigate to register route', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester.element(find.byType(Scaffold)).goToRegister();

      await tester.pumpAndSettle();
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets(
      'goToFeatureFlagsDebug should navigate to feature flags route',
      (tester) async {
        await tester.pumpWidget(createTestWidget(const SizedBox()));
        await tester.pumpAndSettle();

        tester.element(find.byType(Scaffold)).goToFeatureFlagsDebug();

        await tester.pumpAndSettle();
        expect(find.text('FeatureFlags'), findsOneWidget);
      },
    );

    testWidgets('pushRoute should push a new route', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester.element(find.byType(Scaffold)).pushRoute(AppRoutes.login);

      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('pushRoute should push route with extra data', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester
          .element(find.byType(Scaffold))
          .pushRoute(AppRoutes.login, extra: {'key': 'value'});

      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('pushNamedRoute should push named route', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester
          .element(find.byType(Scaffold))
          .pushNamedRoute('login', pathParameters: {}, queryParameters: {});

      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('pushNamedRoute should handle path parameters', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester
          .element(find.byType(Scaffold))
          .pushNamedRoute(
            'demo-detail',
            pathParameters: {'demoId': 'x-789'},
          );

      await tester.pumpAndSettle();
      expect(find.text('Demo x-789'), findsOneWidget);
    });

    testWidgets('pushNamedRoute should handle query parameters', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester
          .element(find.byType(Scaffold))
          .pushNamedRoute(
            'login',
            queryParameters: {'filter': 'active'},
          );

      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('replaceRoute should replace current route', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester.element(find.byType(Scaffold)).replaceRoute(AppRoutes.login);

      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('replaceRoute should replace route with extra data', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester
          .element(find.byType(Scaffold))
          .replaceRoute(AppRoutes.login, extra: {'key': 'value'});

      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('replaceNamedRoute should replace with named route', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester
          .element(find.byType(Scaffold))
          .replaceNamedRoute(
            'register',
            pathParameters: {},
            queryParameters: {},
          );

      await tester.pumpAndSettle();
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('popRoute should pop current route', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      context.popRoute<void>();

      await tester.pumpAndSettle();
    });

    testWidgets('popRoute should pop with result', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      context.popRoute<String>('result');

      await tester.pumpAndSettle();
    });

    testWidgets('popUntilRoute should pop until specific route', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      context.popUntilRoute(AppRoutes.home);

      await tester.pumpAndSettle();
    });

    testWidgets('canPopRoute should return true when can pop', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      final canPop = context.canPopRoute();

      expect(canPop, isTrue);
    });

    testWidgets('canPopRoute should return false when cannot pop', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      final canPop = tester.element(find.byType(Scaffold)).canPopRoute();

      expect(canPop, isFalse);
    });

    testWidgets('popOrGoToHome should pop when can pop', (tester) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      context.popOrGoToHome();

      await tester.pumpAndSettle();
    });

    testWidgets('popOrGoToHome should go to home when cannot pop', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      tester.element(find.byType(Scaffold)).popOrGoToHome();

      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
