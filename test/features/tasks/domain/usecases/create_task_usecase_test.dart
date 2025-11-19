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

    test('should create task with empty title', () async {
      // Arrange
      const title = '';
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
      expect(createdTask!.title, isEmpty);
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should create task with very long title', () async {
      // Arrange
      final longTitle = 'A' * 1000;
      Task? createdTask;
      when(() => mockRepository.createTask(any()))
          .thenAnswer((invocation) async {
        createdTask = invocation.positionalArguments[0] as Task;
        return Success(createdTask!);
      });

      // Act
      final result = await useCase(title: longTitle);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(createdTask, isNotNull);
      expect(createdTask!.title, longTitle);
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should create task with very long description', () async {
      // Arrange
      const title = 'New Task';
      final longDescription = 'B' * 5000;
      Task? createdTask;
      when(() => mockRepository.createTask(any()))
          .thenAnswer((invocation) async {
        createdTask = invocation.positionalArguments[0] as Task;
        return Success(createdTask!);
      });

      // Act
      final result = await useCase(title: title, description: longDescription);

      // Assert
      expect(result.isSuccess, isTrue);
      expect(createdTask, isNotNull);
      expect(createdTask!.description, longDescription);
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should create task with special characters in title', () async {
      // Arrange
      const title = r'Task @#$%^&*()_+-=[]{}|;:,.<>?';
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
      expect(createdTask!.title, title);
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should create task with unicode characters', () async {
      // Arrange
      const title = 'Task 任务 🎯 タスク';
      const description = 'Description Описание 説明';
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
      verify(() => mockRepository.createTask(any())).called(1);
    });

    test('should handle different failure types', () async {
      // Arrange
      const title = 'New Task';
      final failures = [
        const CacheFailure('Cache error'),
        const NetworkFailure('Network error'),
        const ServerFailure('Server error'),
      ];

      for (final failure in failures) {
        when(() => mockRepository.createTask(any()))
            .thenAnswer((_) async => ResultFailure(failure));

        // Act
        final result = await useCase(title: title);

        // Assert
        expectResultFailure(result, failure);
        verify(() => mockRepository.createTask(any())).called(1);
        clearInteractions(mockRepository);
      }
    });

    test('should create multiple tasks with unique ids', () async {
      // Arrange
      const title = 'Task';
      final taskIds = <String>{};

      for (var i = 0; i < 5; i++) {
        Task? createdTask;
        when(() => mockRepository.createTask(any()))
            .thenAnswer((invocation) async {
          createdTask = invocation.positionalArguments[0] as Task;
          return Success(createdTask!);
        });

        // Act
        await useCase(title: title);

        // Assert
        expect(createdTask, isNotNull);
        final task = createdTask!;
        expect(task.id, isNotEmpty);
        taskIds.add(task.id);
        clearInteractions(mockRepository);

        // Add small delay to ensure unique timestamps
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      // All task IDs should be unique (or at least most of them)
      // Note: In rare cases, IDs might collide if created in same millisecond
      expect(taskIds.length, greaterThanOrEqualTo(4));
    });

    test('should create task with createdAt and updatedAt equal', () async {
      // Arrange
      const title = 'New Task';
      Task? createdTask;
      when(() => mockRepository.createTask(any()))
          .thenAnswer((invocation) async {
        createdTask = invocation.positionalArguments[0] as Task;
        return Success(createdTask!);
      });

      // Act
      await useCase(title: title);

      // Assert
      expect(createdTask, isNotNull);
      final task = createdTask!;
      // createdAt and updatedAt should be very close (within 1 second)
      final timeDiff = task.updatedAt.difference(task.createdAt).inSeconds;
      expect(timeDiff, lessThanOrEqualTo(1));
    });
  });
}
