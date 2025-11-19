import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/create_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';
import '../../../../helpers/test_helpers.dart';

class MockTasksRepository extends Mock implements TasksRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(createTask());
  });

  group('CreateTaskUseCase', () {
    late CreateTaskUseCase useCase;
    late MockTasksRepository mockRepository;

    setUp(() {
      mockRepository = MockTasksRepository();
      useCase = CreateTaskUseCase(mockRepository);
    });

    test('should create task with title and description', () async {
      // Arrange
      const title = 'New Task';
      const description = 'Task description';
      Task? createdTask;
      when(() => mockRepository.createTask(any()))
          .thenAnswer((invocation) async {
        createdTask = invocation.positionalArguments[0] as Task;
        return Success(createdTask!);
      });

      // Act
      final result = await useCase(title: title, description: description);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(createdTask, isNotNull);
      final task = createdTask!;
      expect(task.title, title);
      expect(task.description, description);
      expect(task.isCompleted, isFalse);
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should create task with title only', () async {
      // Arrange
      const title = 'New Task';
      Task? createdTask;
      when(() => mockRepository.createTask(any()))
          .thenAnswer((invocation) async {
        createdTask = invocation.positionalArguments[0] as Task;
        return Success(createdTask!);
      });

      // Act
      final result = await useCase(title: title);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(createdTask, isNotNull);
      final task = createdTask!;
      expect(task.title, title);
      expect(task.description, isNull);
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should create task with generated id and timestamps', () async {
      // Arrange
      const title = 'New Task';
      final beforeCreation = DateTime.now();
      Task? createdTask;
      when(() => mockRepository.createTask(any()))
          .thenAnswer((invocation) async {
        createdTask = invocation.positionalArguments[0] as Task;
        return Success(createdTask!);
      });

      // Act
      await useCase(title: title);
      final afterCreation = DateTime.now();

      // Assert
      expect(createdTask, isNotNull);
      final task = createdTask!;
      expect(task.id, isNotEmpty);
      expect(
        task.createdAt.isAfter(beforeCreation) ||
            task.createdAt.isAtSameMomentAs(beforeCreation),
        isTrue,
      );
      expect(
        task.createdAt.isBefore(afterCreation) ||
            task.createdAt.isAtSameMomentAs(afterCreation),
        isTrue,
      );
      expect(
        task.updatedAt.isAfter(beforeCreation) ||
            task.updatedAt.isAtSameMomentAs(beforeCreation),
        isTrue,
      );
      expect(
        task.updatedAt.isBefore(afterCreation) ||
            task.updatedAt.isAtSameMomentAs(afterCreation),
        isTrue,
      );
    });

    test('should return failure when repository fails', () async {
      // Arrange
      const title = 'New Task';
      const failure = CacheFailure('Failed to create task');
      when(() => mockRepository.createTask(any()))
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await useCase(title: title);

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should delegate to repository with correct task', () async {
      // Arrange
      const title = 'Test Task';
      const description = 'Test Description';
      Task? passedTask;
      when(() => mockRepository.createTask(any()))
          .thenAnswer((invocation) async {
        passedTask = invocation.positionalArguments[0] as Task;
        return Success(passedTask!);
      });

      // Act
      await useCase(title: title, description: description);

      // Assert
      expect(passedTask, isNotNull);
      final task = passedTask!;
      expect(task.title, title);
      expect(task.description, description);
      verify(() => mockRepository.createTask(any())).called(1);
    });
  });
}
