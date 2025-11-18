import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';
import '../../../../helpers/test_helpers.dart';

class MockTasksRepository extends Mock implements TasksRepository {}

void main() {
  group('GetTaskByIdUseCase', () {
    late GetTaskByIdUseCase useCase;
    late MockTasksRepository mockRepository;

    setUp(() {
      mockRepository = MockTasksRepository();
      useCase = GetTaskByIdUseCase(mockRepository);
    });

    test('should return task when repository succeeds', () async {
      // Arrange
      const taskId = 'task-1';
      final task = createTask(id: taskId);
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, task);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });

    test('should return null when task not found', () async {
      // Arrange
      const taskId = 'non-existent-task';
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, null);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });

    test('should return failure when repository fails', () async {
      // Arrange
      const taskId = 'task-1';
      const failure = CacheFailure('Failed to get task');
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });

    test('should delegate to repository with correct id', () async {
      // Arrange
      const taskId = 'task-123';
      final task = createTask(id: taskId);
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      await useCase(taskId);

      // Assert
      verify(() => mockRepository.getTaskById(taskId)).called(1);
      verifyNever(() => mockRepository.getTaskById('other-id'));
    });
  });
}
