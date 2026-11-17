// Task paths interpolated the id as is, so an id holding `/`, `?` or `#`
// (any backend's id format, not the starter's own) opened a different route.
// Both ways in - goToTaskDetail and the list's tap - now encode it.

import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_fixtures.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(id: '1', email: 'test@example.com'),
  );
}

class _MockGetTaskByIdUseCase extends Mock implements GetTaskByIdUseCase {}

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

const _id = 'a/b?c#d e';

void main() {
  late _MockGetTaskByIdUseCase getTaskById;

  Future<void> pump(WidgetTester tester, {required bool fromList}) async {
    getTaskById = _MockGetTaskByIdUseCase();
    final getAllTasks = _MockGetAllTasksUseCase();
    final task = createTask(id: _id, title: 'Odd id');
    when(() => getTaskById(any())).thenAnswer((_) async => Success(task));
    when(getAllTasks.call).thenAnswer((_) async => Success(<Task>[task]));
    final router = await pumpAppRouter(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
        sessionRestorationProvider.overrideWith((ref) async {}),
        getTaskByIdUseCaseProvider.overrideWithValue(getTaskById),
        getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
      ],
    );
    router.go(AppRoutes.tasks);
    await tester.pumpAndSettle();
    if (fromList) {
      await tester.tap(find.text('Odd id'));
    } else {
      tester.element(find.byType(Scaffold).last).goToTaskDetail(_id);
    }
    await tester.pumpAndSettle();
  }

  for (final fromList in [false, true]) {
    testWidgets(
      'an id with / ? # opens its own detail screen '
      '(${fromList ? 'tapped in the list' : 'goToTaskDetail'})',
      (tester) async {
        await pump(tester, fromList: fromList);

        final detail = tester.widget<TaskDetailScreen>(
          find.byType(TaskDetailScreen),
        );
        expect(detail.taskId, _id);
        verify(() => getTaskById(_id)).called(greaterThanOrEqualTo(1));
      },
    );
  }
}
