import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/update_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';
import '../../../../helpers/test_helpers.dart';

class MockTasksRepository extends Mock implements TasksRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(createTask());
  });

  group('UpdateTaskUseCase', () {
    late UpdateTaskUseCase useCase;
    late MockTasksRepository mockRepository;

    setUp(() {
      mockRepository = MockTasksRepository();
      useCase = UpdateTaskUseCase(mockRepository);
    });

    test('should update task with new updatedAt timestamp', () async {
      // Arrange
      final testDate = DateTime(2024);
      final originalTask = createTask(
        id: 'task-1',
        title: 'Original Title',
        updatedAt: testDate,
      );
      Task? updatedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        updatedTask = invocation.positionalArguments[0] as Task;
        return Success(updatedTask!);
      });

      // Act
      final result = await useCase(originalTask);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(updatedTask, isNotNull);
      final task = updatedTask!;
      expect(task.id, originalTask.id);
      expect(task.title, originalTask.title);
      expect(task.updatedAt.isAfter(originalTask.updatedAt), isTrue);
      verify(() => mockRepository.updateTask(any())).called(1);
    });

    test('should preserve task properties except updatedAt', () async {
      // Arrange
      final testDate = DateTime(2024);
      final originalTask = createTask(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
        createdAt: testDate,
        updatedAt: testDate,
      );
      Task? updatedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        updatedTask = invocation.positionalArguments[0] as Task;
        return Success(updatedTask!);
      });

      // Act
      await useCase(originalTask);

      // Assert
      expect(updatedTask, isNotNull);
      final task = updatedTask!;
      expect(task.id, originalTask.id);
      expect(task.title, originalTask.title);
      expect(task.description, originalTask.description);
      expect(task.isCompleted, originalTask.isCompleted);
      expect(task.createdAt, originalTask.createdAt);
      expect(task.updatedAt.isAfter(originalTask.updatedAt), isTrue);
    });

    test('should return failure when repository fails', () async {
      // Arrange
      final task = createTask(id: 'task-1');
      const failure = CacheFailure('Failed to update task');
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await useCase(task);

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.updateTask(any())).called(1);
    });

    test('should delegate to repository with correct task', () async {
      // Arrange
      final task = createTask(id: 'task-1');
      Task? passedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        passedTask = invocation.positionalArguments[0] as Task;
        return Success(passedTask!);
      });

      // Act
      await useCase(task);

      // Assert
      expect(passedTask, isNotNull);
      expect(passedTask!.id, task.id);
      verify(() => mockRepository.updateTask(any())).called(1);
    });

    test('should update task with null description', () async {
      // Arrange
      final originalTask = createTask(
        id: 'task-1',
        title: 'Task Title',
      );
      Task? updatedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        updatedTask = invocation.positionalArguments[0] as Task;
        return Success(updatedTask!);
      });

      // Act
      final result = await useCase(originalTask);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(updatedTask, isNotNull);
      final task = updatedTask!;
      expect(task.description, isNull);
      expect(task.updatedAt.isAfter(originalTask.updatedAt), isTrue);
    });

    test('should update task with empty title', () async {
      // Arrange
      final originalTask = createTask(
        id: 'task-1',
        title: '',
      );
      Task? updatedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        updatedTask = invocation.positionalArguments[0] as Task;
        return Success(updatedTask!);
      });

      // Act
      final result = await useCase(originalTask);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(updatedTask, isNotNull);
      final task = updatedTask!;
      expect(task.title, isEmpty);
      expect(task.updatedAt.isAfter(originalTask.updatedAt), isTrue);
    });

    test('should update task with very long title', () async {
      // Arrange
      final longTitle = 'A' * 1000;
      final originalTask = createTask(
        id: 'task-1',
        title: longTitle,
      );
      Task? updatedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        updatedTask = invocation.positionalArguments[0] as Task;
        return Success(updatedTask!);
      });

      // Act
      final result = await useCase(originalTask);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(updatedTask, isNotNull);
      final task = updatedTask!;
      expect(task.title, longTitle);
      expect(task.updatedAt.isAfter(originalTask.updatedAt), isTrue);
    });

    test('should handle task with same createdAt and updatedAt', () async {
      // Arrange
      final testDate = DateTime(2024);
      final originalTask = createTask(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
      );
      Task? updatedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        updatedTask = invocation.positionalArguments[0] as Task;
        return Success(updatedTask!);
      });

      // Act
      final result = await useCase(originalTask);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(updatedTask, isNotNull);
      final task = updatedTask!;
      expect(task.createdAt, testDate);
      expect(task.updatedAt.isAfter(testDate), isTrue);
    });

    test('should handle different failure types', () async {
      // Arrange
      final task = createTask(id: 'task-1');
      final failures = [
        const CacheFailure('Cache error'),
        const NetworkFailure('Network error'),
        const ServerFailure('Server error'),
      ];

      for (final failure in failures) {
        when(() => mockRepository.updateTask(any()))
            .thenAnswer((_) async => ResultFailure(failure));

        // Act
        final result = await useCase(task);

        // Assert
        expectResultFailure(result, failure);
        verify(() => mockRepository.updateTask(any())).called(1);
        clearInteractions(mockRepository);
      }
    });

    test('should update task with all fields changed', () async {
      // Arrange
      final originalTask = createTask(
        id: 'task-1',
        title: 'Original Title',
        description: 'Original Description',
      );
      final updatedTask = originalTask.copyWith(
        title: 'Updated Title',
        description: 'Updated Description',
        isCompleted: true,
      );
      Task? passedTask;
      when(() => mockRepository.updateTask(any()))
          .thenAnswer((invocation) async {
        passedTask = invocation.positionalArguments[0] as Task;
        return Success(passedTask!);
      });

      // Act
      final result = await useCase(updatedTask);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(passedTask, isNotNull);
      final task = passedTask!;
      expect(task.title, 'Updated Title');
      expect(task.description, 'Updated Description');
      expect(task.isCompleted, isTrue);
      expect(task.updatedAt.isAfter(updatedTask.updatedAt), isTrue);
    });

    test('should update task multiple times with increasing timestamps',
        () async {
      // Arrange
      final baseDate = DateTime(2024);
      var previousUpdatedAt = baseDate;

      for (var i = 0; i < 3; i++) {
        final currentTask = createTask(
          id: 'task-1',
          updatedAt: previousUpdatedAt,
        );
        Task? updatedTask;
        when(() => mockRepository.updateTask(any()))
            .thenAnswer((invocation) async {
          updatedTask = invocation.positionalArguments[0] as Task;
          return Success(updatedTask!);
        });

        // Act
        await useCase(currentTask);

        // Assert
        expect(updatedTask, isNotNull);
        final task = updatedTask!;
        expect(task.updatedAt.isAfter(previousUpdatedAt), isTrue);
        previousUpdatedAt = task.updatedAt;
        clearInteractions(mockRepository);
      }
    });
  });
}
