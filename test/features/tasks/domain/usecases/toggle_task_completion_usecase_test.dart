import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/toggle_task_completion_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';
import '../../../../helpers/test_helpers.dart';

class MockTasksRepository extends Mock implements TasksRepository {}

void main() {
  group('ToggleTaskCompletionUseCase', () {
    late ToggleTaskCompletionUseCase useCase;
    late MockTasksRepository mockRepository;

    setUp(() {
      mockRepository = MockTasksRepository();
      useCase = ToggleTaskCompletionUseCase(mockRepository);
    });

    test('should toggle task completion successfully', () async {
      // Arrange
      const taskId = 'task-1';
      final task = createTask(id: taskId);
      when(() => mockRepository.toggleTaskCompletion(any()))
          .thenAnswer((_) async => Success(task.copyWith(isCompleted: true)));

      // Act
      final result = await useCase(taskId);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.isCompleted, isTrue);
      verify(() => mockRepository.toggleTaskCompletion(taskId)).called(1);
    });

    test('should toggle from completed to incomplete', () async {
      // Arrange
      const taskId = 'task-1';
      final task = createTask(id: taskId, isCompleted: true);
      when(() => mockRepository.toggleTaskCompletion(any()))
          .thenAnswer((_) async => Success(task.copyWith(isCompleted: false)));

      // Act
      final result = await useCase(taskId);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.isCompleted, isFalse);
      verify(() => mockRepository.toggleTaskCompletion(taskId)).called(1);
    });

    test('should return failure when repository fails', () async {
      // Arrange
      const taskId = 'task-1';
      const failure = CacheFailure('Failed to toggle task');
      when(() => mockRepository.toggleTaskCompletion(any()))
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await useCase(taskId);

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.toggleTaskCompletion(taskId)).called(1);
    });

    test('should delegate to repository with correct id', () async {
      // Arrange
      const taskId = 'task-123';
      final task = createTask(id: taskId);
      when(() => mockRepository.toggleTaskCompletion(any()))
          .thenAnswer((_) async => Success(task));

      // Act
      await useCase(taskId);

      // Assert
      verify(() => mockRepository.toggleTaskCompletion(taskId)).called(1);
      verifyNever(() => mockRepository.toggleTaskCompletion('other-id'));
    });
  });
}
