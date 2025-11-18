import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';
import '../../../../helpers/test_helpers.dart';

class MockTasksRepository extends Mock implements TasksRepository {}

void main() {
  group('GetAllTasksUseCase', () {
    late GetAllTasksUseCase useCase;
    late MockTasksRepository mockRepository;

    setUp(() {
      mockRepository = MockTasksRepository();
      useCase = GetAllTasksUseCase(mockRepository);
    });

    test('should return list of tasks when repository succeeds', () async {
      // Arrange
      final tasks = createTaskList();
      when(() => mockRepository.getAllTasks())
          .thenAnswer((_) async => Success(tasks));

      // Act
      final result = await useCase();

      // Assert
      expectResultSuccess(result, tasks);
      verify(() => mockRepository.getAllTasks()).called(1);
    });

      test(
        'should return empty list when repository returns empty list',
        () async {
        // Arrange
        when(() => mockRepository.getAllTasks())
            .thenAnswer((_) async => const Success<List<Task>>([]));

        // Act
        final result = await useCase();

        // Assert
        expectResultSuccess(result, <Task>[]);
        verify(() => mockRepository.getAllTasks()).called(1);
        },
      );

    test('should return failure when repository fails', () async {
      // Arrange
      const failure = CacheFailure('Failed to get tasks');
      when(() => mockRepository.getAllTasks())
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await useCase();

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.getAllTasks()).called(1);
    });

    test('should delegate to repository', () async {
      // Arrange
      final tasks = createTaskList(count: 2);
      when(() => mockRepository.getAllTasks())
          .thenAnswer((_) async => Success(tasks));

      // Act
      await useCase();

      // Assert
      verify(() => mockRepository.getAllTasks()).called(1);
    });
  });
}
