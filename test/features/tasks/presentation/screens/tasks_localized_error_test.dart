import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';

// koniz-dev/flutter-starter#415: TasksNotifier and TaskDetailScreen stored
// `failure.message` - English text built for logs - and the tasks screens
// rendered it verbatim, so a Vietnamese user saw English transport text.

class _FailingTasksRepository extends Mock implements TasksRepository {}

const _offline = NetworkFailure(
  'Connection error: The connection errored: Failed host lookup. This '
  'indicates an error which most likely cannot be solved by the library.',
  code: 'CONNECTION_ERROR',
);

const _vi = Locale('vi');

Future<void> _pump(WidgetTester tester, Widget screen, TasksRepository repo) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: _vi,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: screen,
      ),
    ),
  );
}

void main() {
  late _FailingTasksRepository repo;
  final vi = lookupAppLocalizations(_vi);

  setUpAll(() => registerFallbackValue(createTask()));

  setUp(() {
    repo = _FailingTasksRepository();
    when(
      () => repo.getAllTasks(),
    ).thenAnswer((_) async => const ResultFailure<List<Task>>(_offline));
    when(
      () => repo.getTaskById(any()),
    ).thenAnswer((_) async => const ResultFailure<Task?>(_offline));
  });

  void expectNoTransportText() {
    expect(find.textContaining('Connection error'), findsNothing);
    expect(find.textContaining('cannot be solved'), findsNothing);
  }

  testWidgets('criterion 2: the list error is the vi string for the code', (
    tester,
  ) async {
    await _pump(tester, const TasksListScreen(), repo);
    await tester.pumpAndSettle();

    expect(find.text(vi.failureNoConnection), findsOneWidget);
    expectNoTransportText();
  });

  testWidgets('criterion 2: the detail load error is the vi string', (
    tester,
  ) async {
    await _pump(tester, const TaskDetailScreen(taskId: 'task-1'), repo);
    await tester.pumpAndSettle();

    expect(find.text(vi.failureNoConnection), findsOneWidget);
    expectNoTransportText();
  });

  testWidgets('a missing task reads as the vi not-found string', (
    tester,
  ) async {
    when(
      () => repo.getTaskById(any()),
    ).thenAnswer((_) async => const Success<Task?>(null));

    await _pump(tester, const TaskDetailScreen(taskId: 'task-1'), repo);
    await tester.pumpAndSettle();

    expect(find.text(vi.failureNotFound), findsOneWidget);
    expect(find.text('Task not found'), findsNothing);
  });

  testWidgets('a failed save on the detail screen is the vi string', (
    tester,
  ) async {
    final task = createTask(id: 'task-1', title: 'Original Title');
    when(
      () => repo.getTaskById(any()),
    ).thenAnswer((_) async => Success<Task?>(task));
    when(() => repo.getAllTasks()).thenAnswer((_) async => Success([task]));
    when(
      () => repo.updateTask(any()),
    ).thenAnswer((_) async => const ResultFailure<Task>(_offline));

    await _pump(tester, const TaskDetailScreen(taskId: 'task-1'), repo);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(find.text(vi.failureNoConnection), findsOneWidget);
    expectNoTransportText();
  });
}
