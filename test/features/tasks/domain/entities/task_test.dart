import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task', () {
    final now = DateTime.now();
    final later = now.add(const Duration(hours: 1));

    test('should create task with required fields', () {
      // Arrange & Act
      final task = Task(
        id: '1',
        title: 'Test Task',
        createdAt: now,
        updatedAt: later,
      );

      // Assert
      expect(task.id, '1');
      expect(task.title, 'Test Task');
      expect(task.description, isNull);
      expect(task.isCompleted, isFalse);
      expect(task.createdAt, now);
      expect(task.updatedAt, later);
    });

    test('should create task with all fields', () {
      // Arrange & Act
      final task = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test Description',
        isCompleted: true,
        createdAt: now,
        updatedAt: later,
      );

      // Assert
      expect(task.id, '1');
      expect(task.title, 'Test Task');
      expect(task.description, 'Test Description');
      expect(task.isCompleted, isTrue);
      expect(task.createdAt, now);
      expect(task.updatedAt, later);
    });

    test('should create task with default isCompleted', () {
      // Arrange & Act
      final task = Task(
        id: '1',
        title: 'Test Task',
        createdAt: now,
        updatedAt: later,
      );

      // Assert
      expect(task.isCompleted, isFalse);
    });

    group('copyWith', () {
      final originalTask = Task(
        id: '1',
        title: 'Original Title',
        description: 'Original Description',
        createdAt: now,
        updatedAt: later,
      );

      test('should return new task with same values when no changes', () {
        // Act
        final copied = originalTask.copyWith();

        // Assert
        expect(copied.id, originalTask.id);
        expect(copied.title, originalTask.title);
        expect(copied.description, originalTask.description);
        expect(copied.isCompleted, originalTask.isCompleted);
        expect(copied.createdAt, originalTask.createdAt);
        expect(copied.updatedAt, originalTask.updatedAt);
        expect(copied, originalTask);
      });

      test('should update id', () {
        // Act
        final copied = originalTask.copyWith(id: '2');

        // Assert
        expect(copied.id, '2');
        expect(copied.title, originalTask.title);
        expect(copied.description, originalTask.description);
        expect(copied.isCompleted, originalTask.isCompleted);
      });

      test('should update title', () {
        // Act
        final copied = originalTask.copyWith(title: 'New Title');

        // Assert
        expect(copied.id, originalTask.id);
        expect(copied.title, 'New Title');
        expect(copied.description, originalTask.description);
      });

      test('should update description', () {
        // Act
        final copied = originalTask.copyWith(description: 'New Description');

        // Assert
        expect(copied.description, 'New Description');
        expect(copied.title, originalTask.title);
      });

      test('should keep original description when the argument is omitted', () {
        // Act
        final copied = originalTask.copyWith();

        // Assert
        expect(copied.description, originalTask.description);
      });

      test('should clear the description when null is passed explicitly', () {
        // Arrange
        expect(originalTask.description, isNotNull);

        // Act
        final copied = originalTask.copyWith(description: null);

        // Assert
        // An explicit null is a request to clear the field, not to keep it:
        // the detail screen relies on this to erase a description.
        expect(copied.description, isNull);
        expect(copied.title, originalTask.title);
        expect(copied.id, originalTask.id);
      });

      test('should update isCompleted', () {
        // Act
        final copied = originalTask.copyWith(isCompleted: true);

        // Assert
        expect(copied.isCompleted, isTrue);
        expect(copied.id, originalTask.id);
      });

      test('should update createdAt', () {
        // Arrange
        final newDate = now.add(const Duration(days: 1));

        // Act
        final copied = originalTask.copyWith(createdAt: newDate);

        // Assert
        expect(copied.createdAt, newDate);
        expect(copied.updatedAt, originalTask.updatedAt);
      });

      test('should update updatedAt', () {
        // Arrange
        final newDate = later.add(const Duration(days: 1));

        // Act
        final copied = originalTask.copyWith(updatedAt: newDate);

        // Assert
        expect(copied.updatedAt, newDate);
        expect(copied.createdAt, originalTask.createdAt);
      });

      test('should update multiple fields', () {
        // Arrange
        final newDate = now.add(const Duration(days: 2));

        // Act
        final copied = originalTask.copyWith(
          title: 'New Title',
          description: 'New Description',
          isCompleted: true,
          updatedAt: newDate,
        );

        // Assert
        expect(copied.title, 'New Title');
        expect(copied.description, 'New Description');
        expect(copied.isCompleted, isTrue);
        expect(copied.updatedAt, newDate);
        expect(copied.id, originalTask.id);
        expect(copied.createdAt, originalTask.createdAt);
      });
    });

    // The completion rule lives here and nowhere else: `TasksRepositoryImpl`
    // applies `toggleCompletion` inside its atomic mutation instead of
    // hand-copying `TaskModel` fields, and `UpdateTaskUseCase` calls `touch`
    // instead of minting its own `DateTime.now()`.
    // Refs koniz-dev/flutter-starter#180.
    group('touch', () {
      test(
        'stamps updatedAt with the given instant and changes nothing else',
        () {
          // Arrange
          final task = Task(
            id: '1',
            title: 'Title',
            description: 'Description',
            isCompleted: true,
            createdAt: now,
            updatedAt: later,
          );
          final at = later.add(const Duration(minutes: 5));

          // Act
          final touched = task.touch(at: at);

          // Assert
          expect(touched.updatedAt, at);
          expect(touched.updatedAt.isAfter(task.updatedAt), isTrue);
          expect(touched.id, task.id);
          expect(touched.title, task.title);
          expect(touched.description, task.description);
          expect(touched.isCompleted, task.isCompleted);
          expect(touched.createdAt, task.createdAt);
        },
      );

      test('defaults the stamp to now, which is after a past updatedAt', () {
        // Arrange
        final task = Task(
          id: '1',
          title: 'Title',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
        );

        // Act
        final touched = task.touch();

        // Assert
        expect(touched.updatedAt.isAfter(task.updatedAt), isTrue);
      });
    });

    group('toggleCompletion', () {
      test('flips isCompleted and advances updatedAt past the input', () {
        // Arrange - an incomplete task last touched in the past.
        final task = Task(
          id: '1',
          title: 'Title',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
        );

        // Act
        final toggled = task.toggleCompletion();

        // Assert
        expect(toggled.isCompleted, isTrue);
        expect(
          toggled.updatedAt.isAfter(task.updatedAt),
          isTrue,
          reason:
              'updatedAt must advance: ${toggled.updatedAt} vs '
              '${task.updatedAt}',
        );
        expect(toggled.id, task.id);
        expect(toggled.title, task.title);
        expect(toggled.createdAt, task.createdAt);
      });

      test('flips a completed task back and still advances updatedAt', () {
        // Arrange
        final task = Task(
          id: '1',
          title: 'Title',
          isCompleted: true,
          createdAt: now,
          updatedAt: later,
        );
        final at = later.add(const Duration(minutes: 1));

        // Act
        final toggled = task.toggleCompletion(at: at);

        // Assert
        expect(toggled.isCompleted, isFalse);
        expect(toggled.updatedAt, at);
        expect(toggled.updatedAt.isAfter(task.updatedAt), isTrue);
      });

      test('keeps a null description null', () {
        // Arrange
        final task = Task(
          id: '1',
          title: 'Title',
          createdAt: now,
          updatedAt: later,
        );

        // Act
        final toggled = task.toggleCompletion(at: later);

        // Assert
        expect(toggled.description, isNull);
      });
    });

    group('equality', () {
      test('should be equal when all fields are same', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description',
          isCompleted: true,
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description',
          isCompleted: true,
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1, task2);
        expect(task1 == task2, isTrue);
      });

      test('should not be equal when id is different', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '2',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1, isNot(task2));
        expect(task1 == task2, isFalse);
      });

      test('should not be equal when title is different', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Task 1',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Task 2',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1, isNot(task2));
      });

      test('should not be equal when description is different', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description 1',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description 2',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1, isNot(task2));
      });

      test(
        'should not be equal when one has description and other does not',
        () {
          // Arrange
          final task1 = Task(
            id: '1',
            title: 'Test Task',
            description: 'Description',
            createdAt: now,
            updatedAt: later,
          );
          final task2 = Task(
            id: '1',
            title: 'Test Task',
            createdAt: now,
            updatedAt: later,
          );

          // Act & Assert
          expect(task1, isNot(task2));
        },
      );

      test('should not be equal when isCompleted is different', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Test Task',
          isCompleted: true,
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1, isNot(task2));
      });

      test('should be equal to itself', () {
        // Arrange
        final task = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task, task);
        expect(task == task, isTrue);
      });

      test('should not be equal to null', () {
        // Arrange
        final task = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task, isNot(null));
      });

      test('should not be equal to different type', () {
        // Arrange
        final task = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task, isNot('string'));
        expect(task, isNot(123));
        expect(task, isNot(<String, dynamic>{}));
      });

      test('should not be equal when updatedAt is different', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = task1.copyWith(
          updatedAt: later.add(const Duration(days: 1)),
        );

        // Act & Assert
        // UpdateTaskUseCase exists solely to stamp updatedAt; if equality
        // ignored it, an update would be indistinguishable from a no-op.
        expect(task1, isNot(task2));
        expect(task1.hashCode, isNot(task2.hashCode));
      });

      test('should not be equal when createdAt is different', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = task1.copyWith(
          createdAt: now.add(const Duration(days: 1)),
        );

        // Act & Assert
        expect(task1, isNot(task2));
        expect(task1.hashCode, isNot(task2.hashCode));
      });
    });

    group('hashCode', () {
      test('should have same hashCode for equal tasks', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description',
          isCompleted: true,
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description',
          isCompleted: true,
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1.hashCode, task2.hashCode);
      });

      test('should have different hashCode for different ids', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '2',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1.hashCode, isNot(task2.hashCode));
      });

      test('should have different hashCode for different titles', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Task 1',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Task 2',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1.hashCode, isNot(task2.hashCode));
      });

      test('should have different hashCode for different descriptions', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description 1',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description 2',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1.hashCode, isNot(task2.hashCode));
      });

      test('should have different hashCode when one has null description', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          description: 'Description',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1.hashCode, isNot(task2.hashCode));
      });

      test('should have different hashCode for different isCompleted', () {
        // Arrange
        final task1 = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );
        final task2 = Task(
          id: '1',
          title: 'Test Task',
          isCompleted: true,
          createdAt: now,
          updatedAt: later,
        );

        // Act & Assert
        expect(task1.hashCode, isNot(task2.hashCode));
      });
    });

    group('edge cases', () {
      test('should handle empty id', () {
        // Arrange & Act
        final task = Task(
          id: '',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.id, isEmpty);
        expect(task.title, 'Test Task');
      });

      test('should handle empty title', () {
        // Arrange & Act
        final task = Task(id: '1', title: '', createdAt: now, updatedAt: later);

        // Assert
        expect(task.id, '1');
        expect(task.title, isEmpty);
      });

      test('should handle empty description', () {
        // Arrange & Act
        final task = Task(
          id: '1',
          title: 'Test Task',
          description: '',
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.description, isEmpty);
      });

      test('should handle long id', () {
        // Arrange
        final longId = 'a' * 1000;

        // Act
        final task = Task(
          id: longId,
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.id.length, 1000);
      });

      test('should handle long title', () {
        // Arrange
        final longTitle = 'a' * 1000;

        // Act
        final task = Task(
          id: '1',
          title: longTitle,
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.title.length, 1000);
      });

      test('should handle long description', () {
        // Arrange
        final longDescription = 'a' * 2000;

        // Act
        final task = Task(
          id: '1',
          title: 'Test Task',
          description: longDescription,
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.description?.length, 2000);
      });

      test('should handle special characters in id', () {
        // Arrange & Act
        final task = Task(
          id: 'task-123_abc.xyz',
          title: 'Test Task',
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.id, 'task-123_abc.xyz');
      });

      test('should handle special characters in title', () {
        // Arrange & Act
        final task = Task(
          id: '1',
          title: r'Task with special: !@#$%^&*()',
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.title, r'Task with special: !@#$%^&*()');
      });

      test('should handle unicode characters', () {
        // Arrange & Act
        final task = Task(
          id: '1',
          title: 'Task 你好世界 🌍',
          description: 'Description with unicode: こんにちは',
          createdAt: now,
          updatedAt: later,
        );

        // Assert
        expect(task.title, 'Task 你好世界 🌍');
        expect(task.description, 'Description with unicode: こんにちは');
      });

      test('should handle same createdAt and updatedAt', () {
        // Arrange & Act
        final task = Task(
          id: '1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: now,
        );

        // Assert
        expect(task.createdAt, now);
        expect(task.updatedAt, now);
      });

      test('should handle updatedAt before createdAt', () {
        // Arrange
        final createdAt = now.add(const Duration(days: 1));
        final updatedAt = now;

        // Act
        final task = Task(
          id: '1',
          title: 'Test Task',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        // Assert
        expect(task.createdAt, createdAt);
        expect(task.updatedAt, updatedAt);
      });
    });

    group('immutability', () {
      test('should be immutable (final fields)', () {
        // Arrange & Act
        final task = Task(
          id: '1',
          title: 'Test Task',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Assert
        expect(task, isA<Task>());
        // Fields are final, cannot be modified
      });

      test('should allow instances in collections', () {
        // Arrange
        final date1 = DateTime(2023);
        final date2 = DateTime(2023, 1, 2);
        final tasks = [
          Task(id: '1', title: 'Task 1', createdAt: date1, updatedAt: date2),
          Task(id: '2', title: 'Task 2', createdAt: date1, updatedAt: date2),
        ];

        // Act & Assert
        expect(tasks.length, 2);
        expect(tasks[0].id, '1');
        expect(tasks[1].id, '2');
      });
    });
  });
}
