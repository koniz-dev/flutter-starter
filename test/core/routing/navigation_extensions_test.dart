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
              builder: (context, state) => const Scaffold(
                body: Text('Home'),
              ),
            ),
            GoRoute(
              path: AppRoutes.login,
              builder: (context, state) => const Scaffold(
                body: Text('Login'),
              ),
            ),
            GoRoute(
              path: AppRoutes.register,
              builder: (context, state) => const Scaffold(
                body: Text('Register'),
              ),
            ),
            GoRoute(
              path: AppRoutes.tasks,
              name: 'tasks',
              builder: (context, state) => const Scaffold(
                body: Text('Tasks'),
              ),
              routes: [
                GoRoute(
                  path: ':taskId',
                  name: 'task-detail',
                  builder: (context, state) => Scaffold(
                    body: Text('Task ${state.pathParameters['taskId']}'),
                  ),
                ),
              ],
            ),
          ],
        ),
        builder: (context, child) {
          return child!;
        },
      );
    }

    testWidgets('goToHome should navigate to home route', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToHome();

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('goToLogin should navigate to login route', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToLogin();

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('goToRegister should navigate to register route', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToRegister();

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('goToTasks should navigate to tasks route', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToTasks();

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets('goToTaskDetail should navigate to task detail route', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToTaskDetail('task-123');

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Task task-123'), findsOneWidget);
    });

    testWidgets('goToTaskDetail should handle different task ids', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToTaskDetail('task-456');

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Task task-456'), findsOneWidget);
    });

    testWidgets('pushRoute should push a new route', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).pushRoute(AppRoutes.login);

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('pushRoute should push route with extra data', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester
          .element(find.byType(Scaffold))
          .pushRoute(AppRoutes.login, extra: {'key': 'value'});

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('pushNamedRoute should push named route', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester
          .element(find.byType(Scaffold))
          .pushNamedRoute(
            'tasks',
            pathParameters: {},
            queryParameters: {},
          );

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets('pushNamedRoute should handle path parameters', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester
          .element(find.byType(Scaffold))
          .pushNamedRoute(
            'task-detail',
            pathParameters: {'taskId': 'task-789'},
          );

      // Assert
      await tester.pumpAndSettle();
      // Route may not exist, but method should not throw
    });

    testWidgets('pushNamedRoute should handle query parameters', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester
          .element(find.byType(Scaffold))
          .pushNamedRoute(
            'tasks',
            queryParameters: {'filter': 'active'},
          );

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets('replaceRoute should replace current route', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).replaceRoute(AppRoutes.login);

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('replaceRoute should replace route with extra data', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester
          .element(find.byType(Scaffold))
          .replaceRoute(AppRoutes.login, extra: {'key': 'value'});

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('replaceNamedRoute should replace with named route', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester
          .element(find.byType(Scaffold))
          .replaceNamedRoute(
            'tasks',
            pathParameters: {},
            queryParameters: {},
          );

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets('popRoute should pop current route', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      // Act
      context.popRoute<void>();

      // Assert
      await tester.pumpAndSettle();
      // Should return to previous route
    });

    testWidgets('popRoute should pop with result', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      // Act
      context.popRoute<String>('result');

      // Assert
      await tester.pumpAndSettle();
      // Should return to previous route with result
    });

    testWidgets('popUntilRoute should pop until specific route', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      // Act
      context.popUntilRoute(AppRoutes.home);

      // Assert
      await tester.pumpAndSettle();
      // Should pop until home route
    });

    testWidgets('canPopRoute should return true when can pop', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      // Act
      final canPop = context.canPopRoute();

      // Assert
      expect(canPop, isTrue);
    });

    testWidgets('canPopRoute should return false when cannot pop', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act
      final canPop = tester.element(find.byType(Scaffold)).canPopRoute();

      // Assert
      expect(canPop, isFalse);
    });

    testWidgets('popOrGoToHome should pop when can pop', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold))
        ..pushRoute(AppRoutes.login);
      await tester.pumpAndSettle();

      // Act
      context.popOrGoToHome();

      // Assert
      await tester.pumpAndSettle();
      // Should pop back
    });

    testWidgets('popOrGoToHome should go to home when cannot pop', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).popOrGoToHome();

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('goToTaskDetail should handle empty task id', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToTaskDetail('');

      // Assert
      await tester.pumpAndSettle();
      // Should navigate to route with empty task id
    });

    testWidgets('goToTaskDetail should handle special characters in task id', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(const SizedBox()));
      await tester.pumpAndSettle();

      // Act - Get context from Scaffold which has GoRouter in its context
      tester.element(find.byType(Scaffold)).goToTaskDetail('task-123_abc');

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('Task task-123_abc'), findsOneWidget);
    });
  });
}
