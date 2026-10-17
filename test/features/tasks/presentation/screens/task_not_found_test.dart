import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_fixtures.dart';

// koniz-dev/flutter-starter#514 (split from #352): the task detail screen's
// not-found state offered Retry, and retrying a lookup for a task that does
// not exist cannot help. It now offers Back; a load *failure* keeps Retry.

class _MockTasksRepository extends Mock implements TasksRepository {}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(id: '1', email: 'test@example.com'),
  );
}

class _MockGetTaskByIdUseCase extends Mock implements GetTaskByIdUseCase {}

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

const _es = Locale('es');

Future<void> _pumpEs(WidgetTester tester, TasksRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: _es,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: const TaskDetailScreen(taskId: 'missing'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final es = lookupAppLocalizations(_es);

  setUpAll(() => registerFallbackValue(createTask()));

  group('under es', () {
    late _MockTasksRepository repo;
    late String esBack;

    setUp(() async {
      repo = _MockTasksRepository();
      when(
        () => repo.getAllTasks(),
      ).thenAnswer((_) async => const Success(<Task>[]));
      esBack = (await GlobalMaterialLocalizations.delegate.load(
        _es,
      )).backButtonTooltip;
    });

    testWidgets('criteria 1-2: not-found is the es message and offers Back, '
        'not Retry', (tester) async {
      when(
        () => repo.getTaskById(any()),
      ).thenAnswer((_) async => const Success<Task?>(null));

      await _pumpEs(tester, repo);

      expect(find.text(es.failureNotFound), findsOneWidget);
      expect(find.text('Task not found'), findsNothing);
      expect(find.text(es.retry), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, esBack),
        findsOneWidget,
        reason: 'the way out is labelled in the user language',
      );
    });

    testWidgets('criterion 3: a load failure still offers Retry, and Retry '
        'reloads', (tester) async {
      when(() => repo.getTaskById(any())).thenAnswer(
        (_) async => const ResultFailure<Task?>(ServerFailure('boom')),
      );

      await _pumpEs(tester, repo);

      expect(find.text(es.retry), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, esBack), findsNothing);

      await tester.tap(find.text(es.retry));
      await tester.pumpAndSettle();
      verify(() => repo.getTaskById('missing')).called(2);
    });
  });

  group("criterion 2: Back leaves the detail route on the app's router", () {
    Future<GoRouter> pumpRouter(WidgetTester tester) {
      final getTaskById = _MockGetTaskByIdUseCase();
      final getAllTasks = _MockGetAllTasksUseCase();
      when(
        () => getTaskById(any()),
      ).thenAnswer((_) async => const Success<Task?>(null));
      when(getAllTasks.call).thenAnswer((_) async => const Success(<Task>[]));
      return pumpAppRouter(
        tester,
        overrides: [
          authNotifierProvider.overrideWith(_TestAuthNotifier.new),
          sessionRestorationProvider.overrideWith((ref) async {}),
          getTaskByIdUseCaseProvider.overrideWithValue(getTaskById),
          getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
        ],
      );
    }

    Future<void> tapBack(WidgetTester tester) async {
      await tester.tap(find.widgetWithIcon(ElevatedButton, Icons.arrow_back));
      await tester.pumpAndSettle();
    }

    testWidgets('opened from the list, Back pops to the list', (tester) async {
      final router = await pumpRouter(tester);
      router.go(AppRoutes.tasks);
      await tester.pumpAndSettle();
      tester
          .element(find.byType(Scaffold).last)
          .pushRoute('${AppRoutes.tasks}/missing');
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);

      await tapBack(tester);

      expect(router.state.uri.toString(), AppRoutes.tasks);
      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(find.byType(TasksListScreen), findsOneWidget);
    });

    testWidgets('deep-linked, with nothing to pop, Back goes to the list', (
      tester,
    ) async {
      final router = await pumpRouter(tester);
      router.go('${AppRoutes.tasks}/missing');
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);

      await tapBack(tester);

      expect(router.state.uri.toString(), AppRoutes.tasks);
      expect(find.byType(TasksListScreen), findsOneWidget);
    });
  });
}
