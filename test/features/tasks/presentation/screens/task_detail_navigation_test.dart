import 'package:flutter/material.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/update_task_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_fixtures.dart';

// `task_detail_screen.dart` called `context.canPop()` / `context.pop()` from
// `package:go_router` directly until #177 moved it onto
// `NavigationExtensions`. This drives the *app's* router - not one assembled
// in the test file - so the assertion is that a user leaving the detail screen
// still lands on the tasks list.
//
// It lives under `test/features/tasks/` on purpose: the strip script deletes
// this directory with the feature, so the `stripped` and `no_tasks` variants
// do not carry a test importing screens they no longer have.

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _MockGetTaskByIdUseCase extends Mock implements GetTaskByIdUseCase {}

class _MockUpdateTaskUseCase extends Mock implements UpdateTaskUseCase {}

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

void main() {
  setUpAll(() => registerFallbackValue(createTask()));

  testWidgets('task detail returns to the tasks list after saving', (
    tester,
  ) async {
    final getTaskById = _MockGetTaskByIdUseCase();
    final updateTask = _MockUpdateTaskUseCase();
    final getAllTasks = _MockGetAllTasksUseCase();
    final task = createTask(id: 'task-1', title: 'Original Title');

    when(() => getTaskById(any())).thenAnswer((_) async => Success(task));
    when(() => updateTask(any())).thenAnswer((_) async => Success(task));
    when(getAllTasks.call).thenAnswer((_) async => Success(<Task>[task]));

    final router = await pumpAppRouter(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(
          () => _TestAuthNotifier(
            const AuthState(
              user: User(id: '1', email: 'test@example.com'),
            ),
          ),
        ),
        sessionRestorationProvider.overrideWith((ref) async {}),
        getTaskByIdUseCaseProvider.overrideWithValue(getTaskById),
        updateTaskUseCaseProvider.overrideWithValue(updateTask),
        getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
      ],
    );

    router.go(AppRoutes.tasks);
    await tester.pumpAndSettle();
    expect(find.byType(TasksListScreen), findsOneWidget);

    // Exactly how `tasks_list_screen.dart` opens a task.
    tester
        .element(find.byType(Scaffold).last)
        .pushRoute('${AppRoutes.tasks}/${task.id}');
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.tasks);
    expect(find.byType(TaskDetailScreen), findsNothing);
    expect(find.byType(TasksListScreen), findsOneWidget);
  });
}
