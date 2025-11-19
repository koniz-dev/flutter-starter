import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/delete_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_helpers.dart';

class MockTasksRepository extends Mock implements TasksRepository {}

void main() {
  group('DeleteTaskUseCase', () {
    late DeleteTaskUseCase useCase;
    late MockTasksRepository mockRepository;

    setUp(() {
      mockRepository = MockTasksRepository();
      useCase = DeleteTaskUseCase(mockRepository);
    });

    test('should delete task successfully', () async {
      // Arrange
      const taskId = 'task-1';
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.deleteTask(taskId)).called(1);
    });

    test('should return failure when repository fails', () async {
      // Arrange
      const taskId = 'task-1';
      const failure = CacheFailure('Failed to delete task');
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.deleteTask(taskId)).called(1);
    });

    test('should delegate to repository with correct id', () async {
      // Arrange
      const taskId = 'task-123';
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      await useCase(taskId);

      // Assert
      verify(() => mockRepository.deleteTask(taskId)).called(1);
      verifyNever(() => mockRepository.deleteTask('other-id'));
    });

    test('should handle deleting non-existent task', () async {
      // Arrange
      const taskId = 'non-existent-task';
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.deleteTask(taskId)).called(1);
    });

    test('should handle empty task id', () async {
      // Arrange
      const taskId = '';
      const failure = CacheFailure('Task ID cannot be empty');
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.deleteTask(taskId)).called(1);
    });

    test('should handle task id with special characters', () async {
      // Arrange
      const taskId = 'task-123_abc-xyz@test';
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.deleteTask(taskId)).called(1);
    });

    test('should handle different failure types', () async {
      // Arrange
      const taskId = 'task-1';
      final failures = [
        const CacheFailure('Cache error'),
        const NetworkFailure('Network error'),
        const ServerFailure('Server error'),
      ];

      for (final failure in failures) {
        when(() => mockRepository.deleteTask(any()))
            .thenAnswer((_) async => ResultFailure(failure));

        // Act
        final result = await useCase(taskId);

        // Assert
        expectResultFailure(result, failure);
        verify(() => mockRepository.deleteTask(taskId)).called(1);
        clearInteractions(mockRepository);
      }
    });

    test('should handle very long task id', () async {
      // Arrange
      final taskId = 'task-${'a' * 1000}';
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.deleteTask(taskId)).called(1);
    });

    test('should handle numeric task id', () async {
      // Arrange
      const taskId = '12345';
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRepository.deleteTask(taskId)).called(1);
    });

    test('should delete multiple tasks sequentially', () async {
      // Arrange
      final taskIds = ['task-1', 'task-2', 'task-3'];
      when(() => mockRepository.deleteTask(any()))
          .thenAnswer((_) async => const Success(null));

      for (final taskId in taskIds) {
        // Act
        final result = await useCase(taskId);

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockRepository.deleteTask(taskId)).called(1);
        clearInteractions(mockRepository);
      }
    });
  });
}
