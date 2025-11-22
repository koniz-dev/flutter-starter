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

    test('should create instance with repository', () {
      // Arrange & Act
      final useCase = GetTaskByIdUseCase(mockRepository);

      // Assert
      expect(useCase, isNotNull);
      expect(useCase.repository, equals(mockRepository));
    });

    test('should have repository property', () {
      // Assert
      expect(useCase.repository, isA<TasksRepository>());
      expect(useCase.repository, equals(mockRepository));
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

    test('should handle empty task id', () async {
      // Arrange
      const taskId = '';
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, null);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });

    test('should handle task id with special characters', () async {
      // Arrange
      const taskId = 'task-123_abc-xyz@test';
      final task = createTask(id: taskId);
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, task);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });

    test('should handle very long task id', () async {
      // Arrange
      final taskId = 'task-${'a' * 1000}';
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, null);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
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
        when(() => mockRepository.getTaskById(any()))
            .thenAnswer((_) async => ResultFailure(failure));

        // Act
        final result = await useCase(taskId);

        // Assert
        expectResultFailure(result, failure);
        verify(() => mockRepository.getTaskById(taskId)).called(1);
        clearInteractions(mockRepository);
      }
    });

    test('should return task with all properties', () async {
      // Arrange
      const taskId = 'task-1';
      final task = createTask(
        id: taskId,
        description: 'Test Description',
        isCompleted: true,
      );
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, task);
      final returnedTask = result.dataOrNull!;
      expect(returnedTask.id, taskId);
      expect(returnedTask.title, 'Test Task');
      expect(returnedTask.description, 'Test Description');
      expect(returnedTask.isCompleted, isTrue);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });

    test('should return task with null description', () async {
      // Arrange
      const taskId = 'task-1';
      final task = createTask(
        id: taskId,
      );
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, task);
      expect(result.dataOrNull?.description, isNull);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });

    test('should handle numeric task id', () async {
      // Arrange
      const taskId = '12345';
      final task = createTask(id: taskId);
      when(() => mockRepository.getTaskById(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultSuccess(result, task);
      verify(() => mockRepository.getTaskById(taskId)).called(1);
    });
  });
}
