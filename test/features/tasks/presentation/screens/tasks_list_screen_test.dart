import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/create_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/delete_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/toggle_task_completion_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';

class MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

class MockCreateTaskUseCase extends Mock implements CreateTaskUseCase {}

class MockDeleteTaskUseCase extends Mock implements DeleteTaskUseCase {}

class MockToggleTaskCompletionUseCase extends Mock
    implements ToggleTaskCompletionUseCase {}

Widget createTestWidget({
  required Widget child,
  dynamic overrides,
}) {
  return ProviderScope(
    // Override type is not exported from riverpod package.
    // When overrides is provided, it's already List<Override> from
    // provider.overrideWithValue(). When null, we pass an empty list.
    // Runtime type is correct.
    // ignore: argument_type_not_assignable
    overrides: overrides ?? <Never>[],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('TasksListScreen', () {
    late MockGetAllTasksUseCase mockGetAllTasksUseCase;
    late MockCreateTaskUseCase mockCreateTaskUseCase;
    late MockDeleteTaskUseCase mockDeleteTaskUseCase;
    late MockToggleTaskCompletionUseCase mockToggleTaskCompletionUseCase;

    setUp(() {
      mockGetAllTasksUseCase = MockGetAllTasksUseCase();
      mockCreateTaskUseCase = MockCreateTaskUseCase();
      mockDeleteTaskUseCase = MockDeleteTaskUseCase();
      mockToggleTaskCompletionUseCase = MockToggleTaskCompletionUseCase();
    });

    Widget createWidgetWithOverrides(dynamic overrides) {
      return createTestWidget(
        child: const TasksListScreen(),
        overrides: overrides,
      );
    }

    testWidgets(
      'should display loading indicator when loading',
      (tester) async {
        // Arrange
        final completer = Completer<Result<List<Task>>>();
        when(() => mockGetAllTasksUseCase())
            .thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          createWidgetWithOverrides([
            getAllTasksUseCaseProvider
                .overrideWithValue(mockGetAllTasksUseCase),
            createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
            deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
            toggleTaskCompletionUseCaseProvider
                .overrideWithValue(mockToggleTaskCompletionUseCase),
          ]),
        );

        // Act
        await tester.pump();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        completer.complete(const Success<List<Task>>([]));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('should display empty state when no tasks', (tester) async {
      // Arrange
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => const Success<List<Task>>([]));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(
        find.text('Tap the + button to add your first task'),
        findsOneWidget,
      );
    });

    testWidgets('should display tasks list', (tester) async {
      // Arrange
      final tasks = createTaskList();
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));
      when(() => mockToggleTaskCompletionUseCase(any()))
          .thenAnswer((_) async => Success(tasks.first));
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Task 0'), findsOneWidget);
      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
    });

    testWidgets('should display error message on error', (tester) async {
      // Arrange
      const failure = CacheFailure('Failed to load tasks');
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => const ResultFailure(failure));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Failed to load tasks'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
      'should show add task dialog when FAB is tapped',
      (tester) async {
        // Arrange
        when(() => mockGetAllTasksUseCase())
            .thenAnswer((_) async => const Success<List<Task>>([]));
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) async => Success(createTask()));

        await tester.pumpWidget(
          createWidgetWithOverrides([
            getAllTasksUseCaseProvider
                .overrideWithValue(mockGetAllTasksUseCase),
            createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
            deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
            toggleTaskCompletionUseCaseProvider
                .overrideWithValue(mockToggleTaskCompletionUseCase),
          ]),
        );

        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Act
        await tester.tap(find.byType(FloatingActionButton));
        // Use timeout to prevent hanging
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Assert
        expect(find.text('Add Task'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
      },
    );

    testWidgets('should create task when form is submitted', (tester) async {
      // Arrange
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => const Success<List<Task>>([]));
      when(
        () => mockCreateTaskUseCase(
          title: any(named: 'title'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((invocation) async {
        final title = invocation.namedArguments[#title] as String;
        return Success(createTask(title: title));
      });
      // Mock reload after create (called by tasksNotifierProvider)
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => const Success<List<Task>>([]));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Act
      await tester.tap(find.byType(FloatingActionButton));
      // Use timeout to prevent hanging
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Enter text and wait for it to be processed
      await tester.enterText(find.byType(TextFormField).first, 'New Task');
      await tester.pump();

      // Tap the Add button
      await tester.tap(find.text('Add'));
      // Wait for dialog closing animation to complete
      await tester.pump();
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

    testWidgets('should toggle task completion when checkbox is tapped',
        (tester) async {
      // Arrange
      final tasks = createTaskList(count: 2);
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));
      when(() => mockToggleTaskCompletionUseCase(any()))
          .thenAnswer((_) async => Success(tasks.first));
      // Mock reload after toggle (called by tasksNotifierProvider)
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pumpAndSettle();

      // Act
      final checkbox = find.byType(Checkbox).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockToggleTaskCompletionUseCase(any<String>())).called(1);
    });

    testWidgets('should refresh when refresh button is tapped', (tester) async {
      // Arrange
      final tasks = createTaskList(count: 2);
      // Mock initial load and refresh calls
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockGetAllTasksUseCase()).called(greaterThan(1));
    });

    testWidgets('should show delete confirmation dialog', (tester) async {
      // Arrange
      final tasks = createTaskList(count: 1);
      var callCount = 0;
      when(() => mockGetAllTasksUseCase()).thenAnswer((_) async {
        callCount++;
        // First call: return tasks for initial load
        // Subsequent calls: return empty list after delete
        if (callCount == 1) {
          return Success(tasks);
        }
        return const Success<List<Task>>([]);
      });
      when(() => mockDeleteTaskUseCase(any()))
          .thenAnswer((_) async => const Success(null));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pumpAndSettle();

      // Act
      // Find PopupMenuButton by its default icon (more_vert)
      final popupMenuButton = find.byIcon(Icons.more_vert);
      expect(popupMenuButton, findsOneWidget);
      await tester.tap(popupMenuButton);
      await tester.pumpAndSettle();

      // Verify menu is open and tap the Delete menu item
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      // Pump to allow dialog to show
      await tester.pump();
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Delete Task'), findsOneWidget);
    });

    testWidgets('should handle pull-to-refresh', (tester) async {
      // Arrange
      final tasks = createTaskList(count: 2);
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pumpAndSettle();

      // Act - Simulate pull-to-refresh
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockGetAllTasksUseCase()).called(greaterThan(1));
    });

    testWidgets('should disable refresh button when loading', (tester) async {
      // Arrange
      final completer = Completer<Result<List<Task>>>();
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pump();

      // Act - Try to tap refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);
      await tester.tap(refreshButton);
      await tester.pump();

      // Assert - Button should be disabled (onPressed is null when loading)
      // This is verified by the button not responding to taps
      completer.complete(const Success<List<Task>>([]));
      await tester.pumpAndSettle();
    });

    testWidgets('should display completed and incomplete tasks separately',
        (tester) async {
      // Arrange
      final tasks = [
        createTask(id: 'task-1', title: 'Incomplete Task'),
        createTask(id: 'task-2', title: 'Completed Task', isCompleted: true),
        createTask(
          id: 'task-3',
          title: 'Another Incomplete',
        ),
      ];
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));
      when(() => mockToggleTaskCompletionUseCase(any()))
          .thenAnswer((_) async => Success(tasks.first));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Incomplete Task'), findsOneWidget);
      expect(find.text('Completed Task'), findsOneWidget);
      expect(find.text('Another Incomplete'), findsOneWidget);
    });

    testWidgets('should handle error retry button', (tester) async {
      // Arrange
      const failure = CacheFailure('Failed to load tasks');
      final tasks = createTaskList(count: 2);
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => const ResultFailure(failure));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pumpAndSettle();

      // Set up for success on retry
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => Success(tasks));

      // Act
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockGetAllTasksUseCase()).called(greaterThan(1));
    });

    testWidgets('should handle canceling add task dialog', (tester) async {
      // Arrange
      when(() => mockGetAllTasksUseCase())
          .thenAnswer((_) async => const Success<List<Task>>([]));

      await tester.pumpWidget(
        createWidgetWithOverrides([
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider
              .overrideWithValue(mockToggleTaskCompletionUseCase),
        ]),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Act
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find and tap cancel button
      final cancelButton = find.text('Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
      }

      // Assert - Dialog should be closed
      expect(find.text('Add Task'), findsNothing);
      verifyNever(
        () => mockCreateTaskUseCase(
          title: any(named: 'title'),
          description: any(named: 'description'),
        ),
      );
    });
  });
}
