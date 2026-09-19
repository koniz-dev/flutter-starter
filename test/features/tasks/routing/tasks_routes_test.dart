import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_fixtures.dart';

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

class _MockGetTaskByIdUseCase extends Mock implements GetTaskByIdUseCase {}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

// Reachability, not route-table shape: these pump the *app's* router and
// assert that the destination screen renders. Until #56 the tasks constants
// and `context.goToTasks()` existed while `routes_registry.dart` registered
// neither, so every screen in this feature was dead code and the old tests
// missed it by building their own router with the routes already in it.

void main() {
  late _MockGetAllTasksUseCase getAllTasks;
  late _MockGetTaskByIdUseCase getTaskById;
  late ProviderContainer container;

  setUp(() {
    getAllTasks = _MockGetAllTasksUseCase();
    getTaskById = _MockGetTaskByIdUseCase();
    when(
      () => getAllTasks(),
    ).thenAnswer((_) async => const Success<List<Task>>([]));
    when(
      () => getTaskById(any()),
    ).thenAnswer((_) async => Success<Task?>(createTask(id: 'task-123')));
  });

  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 3000);
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
        getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
        getTaskByIdUseCaseProvider.overrideWithValue(getTaskById),
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

  String locationOf(GoRouter router) => router.state.uri.toString();

  BuildContext topContext(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  group('AppRoutes tasks constants', () {
    test('paths and names are the ones the route module registers', () {
      expect(AppRoutes.tasks, '/tasks');
      expect(AppRoutes.taskDetail, '/tasks/:taskId');
      expect(AppRoutes.tasksName, 'tasks');
      expect(AppRoutes.taskDetailName, 'task-detail');
      expect(RouteParams.taskId, 'taskId');
      expect(AppRoutes.taskDetail, '${AppRoutes.tasks}/:${RouteParams.taskId}');
    });
  });

  group('buildTasksRoutes', () {
    test('is composed into the app route tree', () {
      final probe = ProviderContainer();
      addTearDown(probe.dispose);
      final routes = probe.read(Provider<List<RouteBase>>(buildAppRoutes));

      final tasks = routes.whereType<GoRoute>().firstWhere(
        (route) => route.path == AppRoutes.tasks,
        orElse: () => throw StateError('Tasks route not registered'),
      );

      expect(tasks.name, AppRoutes.tasksName);
      expect(
        tasks.routes.whereType<GoRoute>().map((r) => r.name),
        contains(AppRoutes.taskDetailName),
      );
    });
  });

  group('tasks routes are reachable from the running app', () {
    testWidgets('goToTasks renders the tasks list screen', (tester) async {
      final router = await pumpRouter(tester);

      topContext(tester).goToTasks();
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.tasks);
      expect(find.byType(TasksListScreen), findsOneWidget);
    });

    testWidgets('goToTaskDetail renders the detail screen for the id', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      topContext(tester).goToTaskDetail('task-123');
      await tester.pumpAndSettle();

      expect(locationOf(router), '/tasks/task-123');
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      verify(() => getTaskById('task-123')).called(1);
    });

    testWidgets('pushNamedRoute resolves the detail route by path parameter', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      topContext(tester).pushNamedRoute(
        AppRoutes.taskDetailName,
        pathParameters: {RouteParams.taskId: 'task-789'},
      );
      await tester.pumpAndSettle();

      expect(locationOf(router), '/tasks/task-789');
      expect(find.byType(TaskDetailScreen), findsOneWidget);
    });

    testWidgets('an empty task id falls back to the list, not the detail', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      // The helper builds `/tasks/`; go_router strips the trailing slash and
      // matches the parent, so the user gets the list rather than a detail
      // screen for no task.
      topContext(tester).goToTaskDetail('');
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.tasks);
      expect(find.byType(TasksListScreen), findsOneWidget);
      expect(find.byType(TaskDetailScreen), findsNothing);
    });

    testWidgets('popUntilRoute unwinds a detail screen back to the list', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      topContext(tester).pushRoute(AppRoutes.tasks);
      await tester.pumpAndSettle();
      topContext(tester).pushRoute('/tasks/task-123');
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);

      topContext(tester).popUntilRoute(AppRoutes.tasks);
      await tester.pumpAndSettle();

      expect(locationOf(router), AppRoutes.tasks);
      expect(find.byType(TasksListScreen), findsOneWidget);
      // Home is still underneath: the stack was unwound, not emptied.
      expect(router.canPop(), isTrue);
    });
  });
}
