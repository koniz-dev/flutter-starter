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
  });
}
