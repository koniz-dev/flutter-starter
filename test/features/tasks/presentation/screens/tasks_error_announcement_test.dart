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
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';

// The tasks error banner and the detail screen's save error were plain text
// that appeared without moving focus, so a screen reader never mentioned them.

class _TasksRepository extends Mock implements TasksRepository {}

const _offline = NetworkFailure('Connection error', code: 'CONNECTION_ERROR');

Future<void> _pump(WidgetTester tester, Widget screen, TasksRepository repo) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: screen,
      ),
    ),
  );
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final task = createTask(id: 'task-1', title: 'Original Title');
  late _TasksRepository repo;

  setUpAll(() => registerFallbackValue(createTask()));

  setUp(() => repo = _TasksRepository());

  void expectLiveRegion(WidgetTester tester, String message) {
    expect(find.text(message), findsOneWidget);
    expect(
      tester.getSemantics(find.text(message)),
      isSemantics(label: message, isLiveRegion: true),
    );
  }

  testWidgets('a failed refresh over a loaded list is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var loads = 0;
    when(() => repo.getAllTasks()).thenAnswer(
      (_) async => loads++ == 0
          ? Success<List<Task>>([task])
          : const ResultFailure<List<Task>>(_offline),
    );

    await _pump(tester, const TasksListScreen(), repo);
    await tester.pumpAndSettle();
    expect(find.text('Original Title'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    // The banner sits above the still-loaded list.
    expect(find.text('Original Title'), findsOneWidget);
    expectLiveRegion(tester, en.failureNoConnection);
    handle.dispose();
  });

  testWidgets('a failed save on the detail screen is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
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

    expectLiveRegion(tester, en.failureNoConnection);
    handle.dispose();
  });
}
