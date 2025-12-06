import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/create_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/delete_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/toggle_task_completion_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/update_task_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';

class MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

class MockCreateTaskUseCase extends Mock implements CreateTaskUseCase {}

class MockUpdateTaskUseCase extends Mock implements UpdateTaskUseCase {}

class MockDeleteTaskUseCase extends Mock implements DeleteTaskUseCase {}

class MockToggleTaskCompletionUseCase extends Mock
    implements ToggleTaskCompletionUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(createTask());
  });

  group('TasksNotifier', () {
    late ProviderContainer container;
    late MockGetAllTasksUseCase mockGetAllTasksUseCase;
    late MockCreateTaskUseCase mockCreateTaskUseCase;
    late MockUpdateTaskUseCase mockUpdateTaskUseCase;
    late MockDeleteTaskUseCase mockDeleteTaskUseCase;
    late MockToggleTaskCompletionUseCase mockToggleTaskCompletionUseCase;

    setUp(() {
      mockGetAllTasksUseCase = MockGetAllTasksUseCase();
      mockCreateTaskUseCase = MockCreateTaskUseCase();
      mockUpdateTaskUseCase = MockUpdateTaskUseCase();
      mockDeleteTaskUseCase = MockDeleteTaskUseCase();
      mockToggleTaskCompletionUseCase = MockToggleTaskCompletionUseCase();

      // Set default mock for getAllTasksUseCase to handle automatic
      // initial load
      when(
        () => mockGetAllTasksUseCase(),
      ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

      container = ProviderContainer(
        overrides: [
          getAllTasksUseCaseProvider.overrideWithValue(mockGetAllTasksUseCase),
          createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
          updateTaskUseCaseProvider.overrideWithValue(mockUpdateTaskUseCase),
          deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
          toggleTaskCompletionUseCaseProvider.overrideWithValue(
            mockToggleTaskCompletionUseCase,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('should load tasks on initialization', () async {
        // Arrange
        final tasks = createTaskList(count: 2);
        final testMockGetAllTasksUseCase = MockGetAllTasksUseCase();
        when(
          testMockGetAllTasksUseCase.call,
        ).thenAnswer((_) => Future.value(Success(tasks)));

        // Create a new container with the mock set up before creation
        final testContainer = ProviderContainer(
          overrides: [
            getAllTasksUseCaseProvider.overrideWithValue(
              testMockGetAllTasksUseCase,
            ),
            createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
            updateTaskUseCaseProvider.overrideWithValue(mockUpdateTaskUseCase),
            deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
            toggleTaskCompletionUseCaseProvider.overrideWithValue(
              mockToggleTaskCompletionUseCase,
            ),
          ],
        );

        // Act
        // Read the provider to trigger initialization
        // Wait for microtask and async operations to complete
        // Poll until tasks are loaded or timeout
        var attempts = 0;
        while (attempts < 50) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final currentState = testContainer.read(tasksNotifierProvider);
          if (currentState.tasks.isNotEmpty && !currentState.isLoading) {
            break;
          }
          attempts++;
        }

        // Assert
        final state = testContainer.read(tasksNotifierProvider);
        expect(state.tasks, tasks);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        verify(testMockGetAllTasksUseCase.call).called(1);

        testContainer.dispose();
      });
    });

    group('refresh', () {
      test('should reload tasks successfully', () async {
        // Arrange
        final tasks = createTaskList();
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(Success(tasks)));

        final notifier = container.read(tasksNotifierProvider.notifier);
        // Wait for initial load to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.refresh();

        // Assert
        final state = container.read(tasksNotifierProvider);
        expect(state.tasks, tasks);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
        // Once on init, once on refresh
        verify(() => mockGetAllTasksUseCase()).called(2);
      });

      test('should handle refresh failure', () async {
        // Arrange
        const failure = CacheFailure('Failed to load tasks');
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const ResultFailure(failure)));

        final notifier = container.read(tasksNotifierProvider.notifier);
        // Wait for initial load to complete (it will fail, but we need to wait)
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.refresh();

        // Assert
        final state = container.read(tasksNotifierProvider);
        expect(state.error, 'Failed to load tasks');
        expect(state.isLoading, isFalse);
      });
    });

    group('createTask', () {
      test('should create task and reload list', () async {
        // Arrange
        final newTask = createTask(id: 'task-new', title: 'New Task');
        final allTasks = createTaskList(count: 2);
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) => Future.value(Success(newTask)));
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(Success(allTasks)));

        final notifier = container.read(tasksNotifierProvider.notifier);
        // Wait for initial load to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.createTask(title: 'New Task');
        // Wait for reload to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).called(1);
        // Once on init, once after create
        verify(() => mockGetAllTasksUseCase()).called(2);
      });

      test('should handle create task failure', () async {
        // Arrange
        const failure = CacheFailure('Failed to create task');
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) => Future.value(const ResultFailure(failure)));
        // Ensure getAllTasksUseCase is set up for initial load
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.createTask(title: 'New Task');

        // Assert
        final state = container.read(tasksNotifierProvider);
        expect(state.error, 'Failed to create task');
        expect(state.isLoading, isFalse);
      });

      test('should set loading state during creation', () async {
        // Arrange
        final newTask = createTask(id: 'task-new');
        // Use a completer to control when the create task completes
        final createCompleter = Completer<Result<Task>>();
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) => createCompleter.future);
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        // Wait for initial load to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        final future = notifier.createTask(title: 'New Task');
        // Small delay to ensure loading state is set
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Assert - check loading state
        final loadingState = container.read(tasksNotifierProvider);
        expect(loadingState.isLoading, isTrue);

        // Complete the create task operation
        createCompleter.complete(Success(newTask));
        await future;
        // Wait for reload to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalState = container.read(tasksNotifierProvider);
        expect(finalState.isLoading, isFalse);
      });
    });

    group('updateTask', () {
      test('should update task and reload list', () async {
        // Arrange
        final task = createTask(id: 'task-1', title: 'Updated Task');
        final allTasks = createTaskList(count: 2);
        when(
          () => mockUpdateTaskUseCase(any()),
        ).thenAnswer((_) => Future.value(Success(task)));
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(Success(allTasks)));

        final notifier = container.read(tasksNotifierProvider.notifier);
        // Wait for initial load to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.updateTask(task);
        // Wait for reload to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockUpdateTaskUseCase(task)).called(1);
        verify(() => mockGetAllTasksUseCase()).called(2);
      });

      test('should handle update task failure', () async {
        // Arrange
        final task = createTask(id: 'task-1');
        const failure = CacheFailure('Failed to update task');
        when(
          () => mockUpdateTaskUseCase(any()),
        ).thenAnswer((_) => Future.value(const ResultFailure(failure)));
        // Ensure getAllTasksUseCase is set up for initial load
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.updateTask(task);

        // Assert
        final state = container.read(tasksNotifierProvider);
        expect(state.error, 'Failed to update task');
        expect(state.isLoading, isFalse);
      });
    });

    group('deleteTask', () {
      test('should delete task and reload list', () async {
        // Arrange
        const taskId = 'task-1';
        final allTasks = createTaskList(count: 1);
        when(
          () => mockDeleteTaskUseCase(any()),
        ).thenAnswer((_) => Future.value(const Success(null)));
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(Success(allTasks)));

        final notifier = container.read(tasksNotifierProvider.notifier);
        // Wait for initial load to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.deleteTask(taskId);
        // Wait for reload to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockDeleteTaskUseCase(taskId)).called(1);
        verify(() => mockGetAllTasksUseCase()).called(2);
      });

      test('should handle delete task failure', () async {
        // Arrange
        const taskId = 'task-1';
        const failure = CacheFailure('Failed to delete task');
        when(
          () => mockDeleteTaskUseCase(any()),
        ).thenAnswer((_) => Future.value(const ResultFailure(failure)));
        // Ensure getAllTasksUseCase is set up for initial load
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.deleteTask(taskId);

        // Assert
        final state = container.read(tasksNotifierProvider);
        expect(state.error, 'Failed to delete task');
        expect(state.isLoading, isFalse);
      });
    });

    group('toggleTaskCompletion', () {
      test('should toggle task completion and reload list', () async {
        // Arrange
        const taskId = 'task-1';
        final task = createTask(id: taskId);
        final allTasks = createTaskList(count: 2);
        when(() => mockToggleTaskCompletionUseCase(any())).thenAnswer(
          (_) => Future.value(
            Success(task.copyWith(isCompleted: true)),
          ),
        );
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(Success(allTasks)));

        final notifier = container.read(tasksNotifierProvider.notifier);
        // Wait for initial load to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.toggleTaskCompletion(taskId);
        // Wait for reload to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockToggleTaskCompletionUseCase(taskId)).called(1);
        verify(() => mockGetAllTasksUseCase()).called(2);
      });

      test('should handle toggle task completion failure', () async {
        // Arrange
        const taskId = 'task-1';
        const failure = CacheFailure('Failed to toggle task');
        when(
          () => mockToggleTaskCompletionUseCase(any()),
        ).thenAnswer((_) => Future.value(const ResultFailure(failure)));
        // Ensure getAllTasksUseCase is set up for initial load
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Act
        await notifier.toggleTaskCompletion(taskId);

        // Assert
        final state = container.read(tasksNotifierProvider);
        expect(state.error, 'Failed to toggle task');
        expect(state.isLoading, isFalse);
      });
    });

    group('edge cases', () {
      test(
        'should clear error on successful operation after failure',
        () async {
          // Arrange
          const failure = CacheFailure('Operation failed');
          when(
            () => mockGetAllTasksUseCase(),
          ).thenAnswer((_) => Future.value(const ResultFailure(failure)));

          final notifier = container.read(tasksNotifierProvider.notifier);
          // Wait for initial load to complete (it will fail)
          await Future<void>.delayed(const Duration(milliseconds: 200));

          var state = container.read(tasksNotifierProvider);
          expect(state.error, 'Operation failed');

          // Set up for success
          final tasks = createTaskList(count: 2);
          when(
            () => mockGetAllTasksUseCase(),
          ).thenAnswer((_) => Future.value(Success(tasks)));

          // Act
          await notifier.refresh();
          // Wait for refresh to complete
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Assert
          state = container.read(tasksNotifierProvider);
          expect(state.error, isNull);
          expect(state.tasks, tasks);
        },
      );

      test('should handle empty tasks list', () async {
        // Arrange
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        // Wait for initial load to complete
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Assert
        final state = container.read(tasksNotifierProvider);
        expect(state.tasks, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);

        // Wait a bit more to ensure all async operations complete before
        // test ends
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      test('should handle createTask with description', () async {
        // Arrange
        final newTask = createTask(id: 'task-new', title: 'New Task');
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) => Future.value(Success(newTask)));
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.createTask(
          title: 'New Task',
          description: 'Task description',
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(
          () => mockCreateTaskUseCase(
            title: 'New Task',
            description: 'Task description',
          ),
        ).called(1);
      });

      test('should handle createTask with null description', () async {
        // Arrange
        final newTask = createTask(id: 'task-new', title: 'New Task');
        when(
          () => mockCreateTaskUseCase(
            title: any(named: 'title'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) => Future.value(Success(newTask)));
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.createTask(title: 'New Task');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(
          () => mockCreateTaskUseCase(
            title: 'New Task',
          ),
        ).called(1);
      });

      test('should handle updateTask with null description', () async {
        // Arrange
        final task = createTask(
          id: 'task-1',
          title: 'Updated Task',
        );
        when(
          () => mockUpdateTaskUseCase(any()),
        ).thenAnswer((_) => Future.value(Success(task)));
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await notifier.updateTask(task);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockUpdateTaskUseCase(task)).called(1);
      });

      test('should handle multiple rapid operations', () async {
        // Arrange
        final tasks = createTaskList(count: 2);
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(Success(tasks)));
        when(
          () => mockToggleTaskCompletionUseCase(any()),
        ).thenAnswer((_) => Future.value(Success(tasks.first)));
        when(
          () => mockDeleteTaskUseCase(any()),
        ).thenAnswer((_) => Future.value(const Success(null)));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act - Perform multiple operations rapidly
        await notifier.toggleTaskCompletion('task-1');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await notifier.deleteTask('task-2');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockToggleTaskCompletionUseCase('task-1')).called(1);
        verify(() => mockDeleteTaskUseCase('task-2')).called(1);
      });

      test('should handle updateTask loading state', () async {
        // Arrange
        final task = createTask(id: 'task-1');
        final updateCompleter = Completer<Result<Task>>();
        when(
          () => mockUpdateTaskUseCase(any()),
        ).thenAnswer((_) => updateCompleter.future);
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        final future = notifier.updateTask(task);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Assert - check loading state
        final loadingState = container.read(tasksNotifierProvider);
        expect(loadingState.isLoading, isTrue);

        // Complete the update
        updateCompleter.complete(Success(task));
        await future;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalState = container.read(tasksNotifierProvider);
        expect(finalState.isLoading, isFalse);
      });

      test('should handle deleteTask loading state', () async {
        // Arrange
        const taskId = 'task-1';
        final deleteCompleter = Completer<Result<void>>();
        when(
          () => mockDeleteTaskUseCase(any()),
        ).thenAnswer((_) => deleteCompleter.future);
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        final future = notifier.deleteTask(taskId);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Assert - check loading state
        final loadingState = container.read(tasksNotifierProvider);
        expect(loadingState.isLoading, isTrue);

        // Complete the delete
        deleteCompleter.complete(const Success(null));
        await future;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalState = container.read(tasksNotifierProvider);
        expect(finalState.isLoading, isFalse);
      });

      test('should handle toggleTaskCompletion loading state', () async {
        // Arrange
        const taskId = 'task-1';
        final task = createTask(id: taskId);
        final toggleCompleter = Completer<Result<Task>>();
        when(
          () => mockToggleTaskCompletionUseCase(any()),
        ).thenAnswer((_) => toggleCompleter.future);
        when(
          () => mockGetAllTasksUseCase(),
        ).thenAnswer((_) => Future.value(const Success<List<Task>>([])));

        final notifier = container.read(tasksNotifierProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        final future = notifier.toggleTaskCompletion(taskId);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Assert - check loading state
        final loadingState = container.read(tasksNotifierProvider);
        expect(loadingState.isLoading, isTrue);

        // Complete the toggle
        toggleCompleter.complete(Success(task));
        await future;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final finalState = container.read(tasksNotifierProvider);
        expect(finalState.isLoading, isFalse);
      });

      test('should handle large tasks list', () async {
        // Arrange
        final tasks = createTaskList(count: 100);
        final testMockGetAllTasksUseCase = MockGetAllTasksUseCase();
        when(
          testMockGetAllTasksUseCase.call,
        ).thenAnswer((_) => Future.value(Success(tasks)));

        // Create a new container with the mock set up before creation
        final testContainer = ProviderContainer(
          overrides: [
            getAllTasksUseCaseProvider.overrideWithValue(
              testMockGetAllTasksUseCase,
            ),
            createTaskUseCaseProvider.overrideWithValue(mockCreateTaskUseCase),
            updateTaskUseCaseProvider.overrideWithValue(mockUpdateTaskUseCase),
            deleteTaskUseCaseProvider.overrideWithValue(mockDeleteTaskUseCase),
            toggleTaskCompletionUseCaseProvider.overrideWithValue(
              mockToggleTaskCompletionUseCase,
            ),
          ],
        );

        // Act - Read the provider to trigger initialization
        // Wait for microtask and async operations to complete
        var attempts = 0;
        while (attempts < 50) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final currentState = testContainer.read(tasksNotifierProvider);
          if (currentState.tasks.length == 100 && !currentState.isLoading) {
            break;
          }
          attempts++;
        }

        // Assert
        final state = testContainer.read(tasksNotifierProvider);
        expect(state.tasks.length, 100);
        expect(state.isLoading, isFalse);

        // Cleanup
        testContainer.dispose();
      });
    });

    group('TasksState', () {
      test('should create state with default values', () {
        // Act
        const state = TasksState();

        // Assert
        expect(state.tasks, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
      });

      test('should create state with custom values', () {
        // Arrange
        final tasks = createTaskList(count: 2);

        // Act
        final state = TasksState(
          tasks: tasks,
          isLoading: true,
          error: 'Test error',
        );

        // Assert
        expect(state.tasks, tasks);
        expect(state.isLoading, isTrue);
        expect(state.error, 'Test error');
      });

      test('should copy state with new values', () {
        // Arrange
        final originalTasks = createTaskList(count: 2);
        final state = TasksState(
          tasks: originalTasks,
          error: 'Original error',
        );

        // Act
        final newTasks = createTaskList();
        final copied = state.copyWith(
          tasks: newTasks,
          isLoading: true,
          error: 'New error',
        );

        // Assert
        expect(copied.tasks, newTasks);
        expect(copied.isLoading, isTrue);
        expect(copied.error, 'New error');
      });

      test('should copy state with partial values', () {
        // Arrange
        final originalTasks = createTaskList(count: 2);
        final state = TasksState(
          tasks: originalTasks,
          error: 'Original error',
        );

        // Act
        final copied = state.copyWith(isLoading: true);

        // Assert
        expect(copied.tasks, originalTasks);
        expect(copied.isLoading, isTrue);
        expect(copied.error, 'Original error');
      });

      test('should clear error when clearError is true', () {
        // Arrange
        const state = TasksState(error: 'Original error');

        // Act
        final copied = state.copyWith(clearError: true);

        // Assert
        expect(copied.error, isNull);
      });

      test('should preserve error when clearError is false', () {
        // Arrange
        const state = TasksState(error: 'Original error');

        // Act
        final copied = state.copyWith();

        // Assert
        expect(copied.error, 'Original error');
      });

      test('should override error when new error is provided', () {
        // Arrange
        const state = TasksState(error: 'Original error');

        // Act
        final copied = state.copyWith(error: 'New error');

        // Assert
        expect(copied.error, 'New error');
      });
    });
  });
}
