import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_starter/features/tasks/data/repositories/tasks_repository_impl.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';
import '../../../../helpers/test_helpers.dart';

class MockTasksLocalDataSource extends Mock implements TasksLocalDataSource {}

/// Stubs [TasksLocalDataSource.mutateTasks] over an in-memory list, the way
/// the real data source behaves: read the stored list, apply the transform,
/// write the result back atomically.
///
/// The returned list is updated in place on every mutation, so a test can
/// assert on exactly what was written.
List<TaskModel> stubMutateTasks(
  MockTasksLocalDataSource mock, [
  List<TaskModel> initial = const [],
]) {
  final stored = <TaskModel>[...initial];
  when(() => mock.mutateTasks(any())).thenAnswer((invocation) async {
    final transform =
        invocation.positionalArguments.first
            as List<TaskModel> Function(List<TaskModel>);
    final next = transform(List<TaskModel>.of(stored));
    stored
      ..clear()
      ..addAll(next);
    return next;
  });
  return stored;
}

void main() {
  setUpAll(() {
    registerFallbackValue(createTaskModel());
    registerFallbackValue((List<TaskModel> tasks) => tasks);
  });

  group('TasksRepositoryImpl', () {
    late TasksRepositoryImpl repository;
    late MockTasksLocalDataSource mockLocalDataSource;

    setUp(() {
      mockLocalDataSource = MockTasksLocalDataSource();
      repository = TasksRepositoryImpl(localDataSource: mockLocalDataSource);
    });

    test('should create instance with localDataSource', () {
      // Arrange & Act
      final repository = TasksRepositoryImpl(
        localDataSource: mockLocalDataSource,
      );

      // Assert
      expect(repository, isNotNull);
      expect(repository.localDataSource, equals(mockLocalDataSource));
    });

    test('should have localDataSource property', () {
      // Assert
      expect(repository.localDataSource, isA<TasksLocalDataSource>());
      expect(repository.localDataSource, equals(mockLocalDataSource));
    });

    group('getAllTasks', () {
      test('should return list of tasks when data source succeeds', () async {
        // Arrange
        final taskModels = [
          createTaskModel(id: 'task-1'),
          createTaskModel(id: 'task-2'),
        ];
        when(
          () => mockLocalDataSource.getAllTasks(),
        ).thenAnswer((_) async => taskModels);

        // Act
        final result = await repository.getAllTasks();

        // Assert
        final expectedTasks = taskModels.map((m) => m.toEntity()).toList();
        expectResultSuccess(result, expectedTasks);
        verify(() => mockLocalDataSource.getAllTasks()).called(1);
      });

      test('should return empty list when data source returns empty', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getAllTasks(),
        ).thenAnswer((_) async => []);

        // Act
        final result = await repository.getAllTasks();

        // Assert
        expectResultSuccess(result, <Task>[]);
        verify(() => mockLocalDataSource.getAllTasks()).called(1);
      });

      test(
        'should return CacheFailure when data source throws CacheException',
        () async {
          // Arrange
          final exception = createCacheException(message: 'Storage error');
          when(() => mockLocalDataSource.getAllTasks()).thenThrow(exception);

          // Act
          final result = await repository.getAllTasks();

          // Assert
          expectResultFailureType(result, CacheFailure);
          verify(() => mockLocalDataSource.getAllTasks()).called(1);
        },
      );
    });

    group('getTaskById', () {
      test('should return task when data source succeeds', () async {
        // Arrange
        const taskId = 'task-1';
        final taskModel = createTaskModel(id: taskId);
        when(
          () => mockLocalDataSource.getTaskById(any()),
        ).thenAnswer((_) async => taskModel);

        // Act
        final result = await repository.getTaskById(taskId);

        // Assert
        expectResultSuccess(result, taskModel.toEntity());
        verify(() => mockLocalDataSource.getTaskById(taskId)).called(1);
      });

      test('should return null when task not found', () async {
        // Arrange
        const taskId = 'non-existent';
        when(
          () => mockLocalDataSource.getTaskById(any()),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getTaskById(taskId);

        // Assert
        expectResultSuccess(result, null);
        verify(() => mockLocalDataSource.getTaskById(taskId)).called(1);
      });

      test(
        'should return CacheFailure when data source throws exception',
        () async {
          // Arrange
          const taskId = 'task-1';
          final exception = createCacheException(message: 'Storage error');
          when(
            () => mockLocalDataSource.getTaskById(any()),
          ).thenThrow(exception);

          // Act
          final result = await repository.getTaskById(taskId);

          // Assert
          expectResultFailureType(result, CacheFailure);
          verify(() => mockLocalDataSource.getTaskById(taskId)).called(1);
        },
      );
    });

    group('createTask', () {
      test('should create task successfully', () async {
        // Arrange
        final task = createTask(id: 'task-1');
        when(
          () => mockLocalDataSource.saveTask(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.createTask(task);

        // Assert
        expectResultSuccess(result, task);
        verify(() => mockLocalDataSource.saveTask(any())).called(1);
      });

      test(
        'should return CacheFailure when data source throws exception',
        () async {
          // Arrange
          final task = createTask(id: 'task-1');
          final exception = createCacheException(message: 'Storage error');
          when(() => mockLocalDataSource.saveTask(any())).thenThrow(exception);

          // Act
          final result = await repository.createTask(task);

          // Assert
          expectResultFailureType(result, CacheFailure);
          verify(() => mockLocalDataSource.saveTask(any())).called(1);
        },
      );
    });

    group('updateTask', () {
      test('should update task successfully', () async {
        // Arrange
        final task = createTask(id: 'task-1', title: 'Updated Title');
        when(
          () => mockLocalDataSource.saveTask(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.updateTask(task);

        // Assert
        expectResultSuccess(result, task);
        verify(() => mockLocalDataSource.saveTask(any())).called(1);
      });

      test(
        'should return CacheFailure when data source throws exception',
        () async {
          // Arrange
          final task = createTask(id: 'task-1');
          final exception = createCacheException(message: 'Storage error');
          when(() => mockLocalDataSource.saveTask(any())).thenThrow(exception);

          // Act
          final result = await repository.updateTask(task);

          // Assert
          expectResultFailureType(result, CacheFailure);
          verify(() => mockLocalDataSource.saveTask(any())).called(1);
        },
      );
    });

    group('deleteTask', () {
      test('should delete task successfully', () async {
        // Arrange
        const taskId = 'task-1';
        when(
          () => mockLocalDataSource.deleteTask(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.deleteTask(taskId);

        // Assert
        expect(result.isSuccess, isTrue, reason: 'Expected success: $result');
        verify(() => mockLocalDataSource.deleteTask(taskId)).called(1);
      });

      test(
        'should return CacheFailure when data source throws exception',
        () async {
          // Arrange
          const taskId = 'task-1';
          final exception = createCacheException(message: 'Storage error');
          when(
            () => mockLocalDataSource.deleteTask(any()),
          ).thenThrow(exception);

          // Act
          final result = await repository.deleteTask(taskId);

          // Assert
          expectResultFailureType(result, CacheFailure);
          verify(() => mockLocalDataSource.deleteTask(taskId)).called(1);
        },
      );
    });

    group('toggleTaskCompletion', () {
      test('should toggle task completion successfully', () async {
        // Arrange
        const taskId = 'task-1';
        final taskModel = createTaskModel(id: taskId);
        final stored = stubMutateTasks(mockLocalDataSource, [taskModel]);

        // Act
        final result = await repository.toggleTaskCompletion(taskId);

        // Assert
        result.when(
          success: (task) => expect(task.isCompleted, isTrue),
          failureCallback: (_) => fail('Expected success'),
        );
        // The flip is computed inside one atomic mutation, so nothing reads
        // the task outside the write lock.
        verify(() => mockLocalDataSource.mutateTasks(any())).called(1);
        verifyNever(() => mockLocalDataSource.getTaskById(any()));
        verifyNever(() => mockLocalDataSource.saveTask(any()));
        expect(stored.single.isCompleted, isTrue);
      });

      test('should return CacheFailure when task not found', () async {
        // Arrange
        const taskId = 'non-existent';
        stubMutateTasks(mockLocalDataSource);

        // Act
        final result = await repository.toggleTaskCompletion(taskId);

        // Assert
        expectResultFailureType(result, CacheFailure);
        result.when(
          success: (_) => fail('Expected failure'),
          failureCallback: (failure) =>
              expect(failure.message, 'Task not found'),
        );
      });

      test(
        'should return CacheFailure when mutateTasks throws exception',
        () async {
          // Arrange
          const taskId = 'task-1';
          final exception = createCacheException(message: 'Storage error');
          when(
            () => mockLocalDataSource.mutateTasks(any()),
          ).thenThrow(exception);

          // Act
          final result = await repository.toggleTaskCompletion(taskId);

          // Assert
          expectResultFailureType(result, CacheFailure);
        },
      );

      test('should toggle from completed to incomplete', () async {
        // Arrange
        const taskId = 'task-1';
        final taskModel = createTaskModel(id: taskId, isCompleted: true);
        stubMutateTasks(mockLocalDataSource, [taskModel]);

        // Act
        final result = await repository.toggleTaskCompletion(taskId);

        // Assert
        result.when(
          success: (task) => expect(task.isCompleted, isFalse),
          failureCallback: (_) => fail('Expected success'),
        );
      });

      test('should update updatedAt when toggling', () async {
        // Arrange
        const taskId = 'task-1';
        final originalTime = DateTime(2023);
        final taskModel = TaskModel(
          id: taskId,
          title: 'Test Task',
          createdAt: originalTime,
          updatedAt: originalTime,
        );
        stubMutateTasks(mockLocalDataSource, [taskModel]);

        // Act
        final result = await repository.toggleTaskCompletion(taskId);

        // Assert
        result.when(
          success: (task) {
            expect(task.updatedAt, isNot(originalTime));
            expect(task.updatedAt.isAfter(originalTime), isTrue);
          },
          failureCallback: (_) => fail('Expected success'),
        );
      });
    });

    group('Error handling', () {
      test('should handle generic Exception in getAllTasks', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getAllTasks(),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.getAllTasks();

        // Assert
        expectResultFailureType(result, UnknownFailure);
      });

      test('should handle generic Exception in getTaskById', () async {
        // Arrange
        const taskId = 'task-1';
        when(
          () => mockLocalDataSource.getTaskById(any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.getTaskById(taskId);

        // Assert
        expectResultFailureType(result, UnknownFailure);
      });

      test('should handle generic Exception in createTask', () async {
        // Arrange
        final task = createTask(id: 'task-1');
        when(
          () => mockLocalDataSource.saveTask(any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.createTask(task);

        // Assert
        expectResultFailureType(result, UnknownFailure);
      });

      test('should handle generic Exception in updateTask', () async {
        // Arrange
        final task = createTask(id: 'task-1');
        when(
          () => mockLocalDataSource.saveTask(any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.updateTask(task);

        // Assert
        expectResultFailureType(result, UnknownFailure);
      });

      test('should handle generic Exception in deleteTask', () async {
        // Arrange
        const taskId = 'task-1';
        when(
          () => mockLocalDataSource.deleteTask(any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.deleteTask(taskId);

        // Assert
        expectResultFailureType(result, UnknownFailure);
      });

      test('should handle generic Exception in toggleTaskCompletion', () async {
        // Arrange
        const taskId = 'task-1';
        when(
          () => mockLocalDataSource.mutateTasks(any()),
        ).thenThrow(Exception('Generic error'));

        // Act
        final result = await repository.toggleTaskCompletion(taskId);

        // Assert
        expectResultFailureType(result, UnknownFailure);
      });
    });

    group('Edge cases', () {
      test('should handle getAllTasks with large list', () async {
        // Arrange
        final taskModels = List.generate(
          100,
          (index) => createTaskModel(id: 'task-$index'),
        );
        when(
          () => mockLocalDataSource.getAllTasks(),
        ).thenAnswer((_) async => taskModels);

        // Act
        final result = await repository.getAllTasks();

        // Assert
        expectResultSuccess(
          result,
          taskModels.map((m) => m.toEntity()).toList(),
        );
        expect(
          result.when(
            success: (tasks) => tasks.length,
            failureCallback: (_) => 0,
          ),
          100,
        );
      });

      test('should handle createTask with task having all fields', () async {
        // Arrange
        final task = createTask(
          id: 'task-1',
          description: 'Test Description',
          isCompleted: true,
        );
        when(
          () => mockLocalDataSource.saveTask(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.createTask(task);

        // Assert
        expectResultSuccess(result, task);
        verify(() => mockLocalDataSource.saveTask(any())).called(1);
      });

      test(
        'should handle updateTask with task having null description',
        () async {
          // Arrange
          final task = createTask(id: 'task-1');
          when(
            () => mockLocalDataSource.saveTask(any()),
          ).thenAnswer((_) async => {});

          // Act
          final result = await repository.updateTask(task);

          // Assert
          expectResultSuccess(result, task);
        },
      );

      test('should handle deleteTask with empty string ID', () async {
        // Arrange
        when(
          () => mockLocalDataSource.deleteTask(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.deleteTask('');

        // Assert
        expect(result.isSuccess, isTrue, reason: 'Expected success: $result');
      });

      test('should handle getTaskById with empty string ID', () async {
        // Arrange
        when(
          () => mockLocalDataSource.getTaskById(any()),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getTaskById('');

        // Assert
        expectResultSuccess(result, null);
      });

      test(
        'should handle toggleTaskCompletion with task already completed',
        () async {
          // Arrange
          const taskId = 'task-1';
          final taskModel = createTaskModel(id: taskId, isCompleted: true);
          final stored = stubMutateTasks(mockLocalDataSource, [taskModel]);

          // Act
          final result = await repository.toggleTaskCompletion(taskId);

          // Assert
          result.when(
            success: (task) => expect(task.isCompleted, isFalse),
            failureCallback: (_) => fail('Expected success'),
          );
          verify(() => mockLocalDataSource.mutateTasks(any())).called(1);
          expect(stored.single.isCompleted, isFalse);
        },
      );
    });
  });
}
