import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/create_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/update_task_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';

class MockGetTaskByIdUseCase extends Mock implements GetTaskByIdUseCase {}

class MockCreateTaskUseCase extends Mock implements CreateTaskUseCase {}

class MockUpdateTaskUseCase extends Mock implements UpdateTaskUseCase {}

class MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

Widget createTestWidget({
  required Widget child,
  dynamic overrides,
}) {
  // Create a simple GoRouter for navigation (needed for context.pop())
  // Use a builder function to ensure router is properly initialized
  final router = GoRouter(
    initialLocation: AppRoutes.tasks,
    routes: [
      GoRoute(
        path: AppRoutes.tasks,
        builder: (context, state) => child,
      ),
    ],
  );

  return ProviderScope(
    // Override type is not exported from riverpod package.
    // When overrides is provided, it's already List<Override> from
    // provider.overrideWithValue(). When null, we pass an empty list.
    // Runtime type is correct.
    // ignore: argument_type_not_assignable
    overrides: overrides ?? <Never>[],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(createTask());
  });

  group('TaskDetailScreen', () {
    late MockGetTaskByIdUseCase mockGetTaskByIdUseCase;
    late MockCreateTaskUseCase mockCreateTaskUseCase;
    late MockUpdateTaskUseCase mockUpdateTaskUseCase;
    late MockGetAllTasksUseCase mockGetAllTasksUseCase;

    setUp(() {
      mockGetTaskByIdUseCase = MockGetTaskByIdUseCase();
      mockCreateTaskUseCase = MockCreateTaskUseCase();
      mockUpdateTaskUseCase = MockUpdateTaskUseCase();
      mockGetAllTasksUseCase = MockGetAllTasksUseCase();
      // Default mock for getAllTasksUseCase (needed by tasksNotifierProvider)
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => const Success<List<Task>>([]));
    });

    Widget createWidgetWithOverrides(
      Widget child,
      dynamic overrides,
    ) {
      return createTestWidget(
        child: child,
        overrides: overrides,
      );
    }

    group('creating new task', () {
      testWidgets('should display form for new task', (tester) async {
        // Arrange
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) async => Success(createTask()));

        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Add Task'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Description'), findsOneWidget);
      });

      testWidgets('should create task when save is tapped', (tester) async {
        // Arrange
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) async => Success(createTask()));

        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Act
        await tester.enterText(find.byType(TextFormField).first, 'New Task');
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        // Assert
        verify(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).called(1);
      });

      testWidgets('should validate required title field', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Please enter a task title'), findsOneWidget);
        verifyNever(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        );
      });
    });

    group('editing existing task', () {
      testWidgets('should display loading indicator while loading task',
          (tester) async {
        // Arrange
        final task = createTask(id: 'task-1');
        final completer = Completer<Result<Task?>>();
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(taskId: 'task-1'),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        // Act - pump to allow initState to run and start loading
        await tester.pump();

        // Assert - should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete the async operation
        completer.complete(Success(task));
        await tester.pumpAndSettle();
      });

      testWidgets('should display task details when loaded', (tester) async {
        // Arrange
        final task = createTask(
          id: 'task-1',
          description: 'Test Description',
        );
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => Success(task));
        when(() => mockUpdateTaskUseCase(any()))
            .thenAnswer((_) async => Success(task));

        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(taskId: 'task-1'),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Edit Task'), findsOneWidget);
        expect(find.text('Test Task'), findsOneWidget);
        expect(find.text('Test Description'), findsOneWidget);
      });

      testWidgets('should display error when task not found', (tester) async {
        // Arrange
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => const Success(null));

        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(taskId: 'non-existent'),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Task not found'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should display error when loading fails', (tester) async {
        // Arrange
        const failure = CacheFailure('Failed to load task');
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => const ResultFailure(failure));

        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(taskId: 'task-1'),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Failed to load task'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should retry loading when retry button is tapped',
          (tester) async {
        // Arrange
        const failure = CacheFailure('Failed to load task');
        final task = createTask(id: 'task-1');
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => const ResultFailure(failure));

        await tester.pumpWidget(
          createWidgetWithOverrides(
            const TaskDetailScreen(taskId: 'task-1'),
            [
              getTaskByIdUseCaseProvider
                  .overrideWithValue(mockGetTaskByIdUseCase),
              createTaskUseCaseProvider
                  .overrideWithValue(mockCreateTaskUseCase),
              updateTaskUseCaseProvider
                  .overrideWithValue(mockUpdateTaskUseCase),
              getAllTasksUseCaseProvider
                  .overrideWithValue(mockGetAllTasksUseCase),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Set up for success on retry
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => Success(task));

        // Act
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Edit Task'), findsOneWidget);
        verify(() => mockGetTaskByIdUseCase(any<String>()))
            .called(greaterThan(1));
      });
    });
  });
}
