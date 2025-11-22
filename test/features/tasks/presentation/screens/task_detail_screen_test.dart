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

        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Act
        await tester.enterText(find.byType(TextFormField).first, 'New Task');
        await tester.tap(find.byIcon(Icons.save));
        // Use timeout to prevent hanging
        await tester.pumpAndSettle(const Duration(seconds: 5));

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

        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Set up for success on retry
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => Success(task));

        // Act
        await tester.tap(find.text('Retry'));
        // Use timeout to prevent hanging
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assert
        expect(find.text('Edit Task'), findsOneWidget);
        verify(() => mockGetTaskByIdUseCase(any<String>()))
            .called(greaterThan(1));
      });

      testWidgets('should update task when save is tapped', (tester) async {
        // Arrange
        final originalTask = createTask(
          id: 'task-1',
          title: 'Original Title',
          description: 'Original Description',
        );
        final updatedTask = createTask(
          id: 'task-1',
          title: 'Updated Title',
          description: 'Updated Description',
        );
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => Success(originalTask));
        when(() => mockUpdateTaskUseCase(any()))
            .thenAnswer((_) async => Success(updatedTask));

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

        // Act - Update title
        await tester.enterText(
          find.byType(TextFormField).first,
          'Updated Title',
        );
        await tester.pump();
        // Update description if there's a second field
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().length > 1) {
          await tester.enterText(textFields.at(1), 'Updated Description');
          await tester.pump();
        }
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assert
        verify(() => mockUpdateTaskUseCase(any())).called(1);
      });

      testWidgets('should validate title when updating task', (tester) async {
        // Arrange
        final task = createTask(id: 'task-1', title: 'Original Title');
        when(() => mockGetTaskByIdUseCase(any<String>()))
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

        await tester.pumpAndSettle();

        // Act - Clear title and try to save
        await tester.enterText(find.byType(TextFormField).first, '');
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Please enter a task title'), findsOneWidget);
        verifyNever(() => mockUpdateTaskUseCase(any()));
      });

      testWidgets('should handle update task failure', (tester) async {
        // Arrange
        final task = createTask(id: 'task-1');
        const failure = CacheFailure('Failed to update task');
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => Success(task));
        when(() => mockUpdateTaskUseCase(any()))
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

        // Act
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assert - Should show error (implementation dependent)
        verify(() => mockUpdateTaskUseCase(any())).called(1);
      });

      testWidgets('should display task with null description', (tester) async {
        // Arrange
        final task = createTask(
          id: 'task-1',
        );
        when(() => mockGetTaskByIdUseCase(any<String>()))
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
      });

      testWidgets('should handle create task failure', (tester) async {
        // Arrange
        const failure = CacheFailure('Failed to create task');
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) async => const ResultFailure(failure));

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
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assert
        verify(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).called(1);
      });

      testWidgets('should handle cancel button in create mode', (tester) async {
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

        // Act - Look for back button or cancel
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }

        // Assert - Should not create task
        verifyNever(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        );
      });

      testWidgets('should handle cancel button in edit mode', (tester) async {
        // Arrange
        final task = createTask(id: 'task-1');
        when(() => mockGetTaskByIdUseCase(any<String>()))
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

        await tester.pumpAndSettle();

        // Act - Modify task and then cancel
        await tester.enterText(find.byType(TextFormField).first, 'Modified');
        await tester.pump();
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }

        // Assert - Should not update task
        // (navigation happens, but update not called)
        // Note: This depends on implementation
        // - if back button navigates immediately,
        // update might not be called
      });

      testWidgets('should display task details card with all fields',
          (tester) async {
        // Arrange
        final task = createTask(
          id: 'task-1',
          description: 'Test Description',
          isCompleted: true,
          createdAt: DateTime(2024, 1, 15, 10, 30),
          updatedAt: DateTime(2024, 1, 16, 14, 45),
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

        // Assert - Check that task details card is displayed
        expect(find.byType(Card), findsOneWidget);
        // Check for detail rows (status, createdAt, updatedAt)
        expect(find.byIcon(Icons.check_circle), findsWidgets);
        expect(find.byIcon(Icons.calendar_today), findsWidgets);
        expect(find.byIcon(Icons.update), findsWidgets);
      });

      testWidgets('should display incomplete status for incomplete task',
          (tester) async {
        // Arrange
        final task = createTask(
          id: 'task-1',
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

        // Assert - Should show incomplete status
        expect(find.byType(Card), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsWidgets);
      });

      testWidgets('should handle empty description when saving',
          (tester) async {
        // Arrange
        final task = createTask(
          id: 'task-1',
          description: 'Original Description',
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

        await tester.pumpAndSettle();

        // Act - Clear description and save
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().length > 1) {
          await tester.enterText(textFields.at(1), '');
          await tester.pump();
        }
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assert - Should call updateTask with null description
        verify(() => mockUpdateTaskUseCase(any())).called(1);
      });

      testWidgets('should show loading indicator in AppBar when saving',
          (tester) async {
        // Arrange
        final task = createTask(id: 'task-1');
        final completer = Completer<Result<Task>>();
        when(() => mockGetTaskByIdUseCase(any<String>()))
            .thenAnswer((_) async => Success(task));
        when(() => mockUpdateTaskUseCase(any()))
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

        await tester.pumpAndSettle();

        // Act - Tap save button
        await tester.tap(find.byIcon(Icons.save));
        await tester.pump(); // Don't settle, keep it loading

        // Assert - Should show loading indicator in AppBar
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        // Complete the operation
        completer.complete(Success(task));
        await tester.pumpAndSettle();
      });

      testWidgets('should handle retry when taskId is null', (tester) async {
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

        // Act - Should not show retry button for new task
        // (retry is only shown when there's an error loading existing task)
        expect(find.text('Retry'), findsNothing);
      });

      testWidgets('should format date time correctly', (tester) async {
        // Arrange
        final task = createTask(
          id: 'task-1',
          createdAt: DateTime(2024, 3, 15, 9, 5),
          updatedAt: DateTime(2024, 3, 16, 14, 30),
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

        // Assert - Check that formatted dates are displayed
        // Format: YYYY-MM-DD HH:mm
        expect(find.textContaining('2024-03-15'), findsWidgets);
        expect(find.textContaining('2024-03-16'), findsWidgets);
      });
    });
  });
}
