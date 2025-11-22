import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_fixtures.dart';

void main() {
  group('TaskModel', () {
    test('should create TaskModel from JSON', () {
      // Arrange
      final json = createTaskJson(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromJson(json);

      // Assert
      expect(taskModel.id, 'task-1');
      expect(taskModel.title, 'Test Task');
      expect(taskModel.description, 'Test Description');
      expect(taskModel.isCompleted, isTrue);
      expect(taskModel.createdAt, isA<DateTime>());
      expect(taskModel.updatedAt, isA<DateTime>());
    });

    test('should create TaskModel from JSON without description', () {
      // Arrange
      final json = createTaskJson(
        id: 'task-1',
      );

      // Act
      final taskModel = TaskModel.fromJson(json);

      // Assert
      expect(taskModel.id, 'task-1');
      expect(taskModel.title, 'Test Task');
      expect(taskModel.description, isNull);
      expect(taskModel.isCompleted, isFalse);
    });

    test('should convert TaskModel to JSON', () {
      // Arrange
      final taskModel = createTaskModel(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final json = taskModel.toJson();

      // Assert
      expect(json['id'], 'task-1');
      expect(json['title'], 'Test Task');
      expect(json['description'], 'Test Description');
      expect(json['is_completed'], isTrue);
      expect(json['created_at'], isA<String>());
      expect(json['updated_at'], isA<String>());
    });

    test('should convert TaskModel to JSON without description', () {
      // Arrange
      final taskModel = createTaskModel(
        id: 'task-1',
      );

      // Act
      final json = taskModel.toJson();

      // Assert
      expect(json['id'], 'task-1');
      expect(json['title'], 'Test Task');
      expect(json['description'], isNull);
      expect(json['is_completed'], isFalse);
    });

    test('should create TaskModel from entity', () {
      // Arrange
      final task = createTask(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromEntity(task);

      // Assert
      expect(taskModel.id, task.id);
      expect(taskModel.title, task.title);
      expect(taskModel.description, task.description);
      expect(taskModel.isCompleted, task.isCompleted);
      expect(taskModel.createdAt, task.createdAt);
      expect(taskModel.updatedAt, task.updatedAt);
    });

    test('should convert TaskModel to entity', () {
      // Arrange
      final taskModel = createTaskModel(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final entity = taskModel.toEntity();

      // Assert
      expect(entity.id, taskModel.id);
      expect(entity.title, taskModel.title);
      expect(entity.description, taskModel.description);
      expect(entity.isCompleted, taskModel.isCompleted);
      expect(entity.createdAt, taskModel.createdAt);
      expect(entity.updatedAt, taskModel.updatedAt);
    });

    test('should handle round-trip conversion (JSON -> Model -> JSON)', () {
      // Arrange
      final originalJson = createTaskJson(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromJson(originalJson);
      final convertedJson = taskModel.toJson();

      // Assert
      expect(convertedJson['id'], originalJson['id']);
      expect(convertedJson['title'], originalJson['title']);
      expect(convertedJson['description'], originalJson['description']);
      expect(convertedJson['is_completed'], originalJson['is_completed']);
    });

    test('should handle round-trip conversion (Entity -> Model -> Entity)', () {
      // Arrange
      final originalTask = createTask(
        id: 'task-1',
        description: 'Test Description',
        isCompleted: true,
      );

      // Act
      final taskModel = TaskModel.fromEntity(originalTask);
      final convertedTask = taskModel.toEntity();

      // Assert
      expect(convertedTask.id, originalTask.id);
      expect(convertedTask.title, originalTask.title);
      expect(convertedTask.description, originalTask.description);
      expect(convertedTask.isCompleted, originalTask.isCompleted);
      expect(convertedTask.createdAt, originalTask.createdAt);
      expect(convertedTask.updatedAt, originalTask.updatedAt);
    });

    group('Edge cases', () {
      test('should handle JSON with null is_completed as false', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'description': null,
          'is_completed': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.isCompleted, isFalse);
      });

      test('should handle JSON with missing is_completed field', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.isCompleted, isFalse);
      });

      test('should handle JSON with empty string description', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'description': '',
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.description, '');
      });

      test('should preserve all fields in toJson', () {
        // Arrange
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          description: 'Test Description',
          isCompleted: true,
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final json = taskModel.toJson();

        // Assert
        expect(json['id'], 'task-1');
        expect(json['title'], 'Test Task');
        expect(json['description'], 'Test Description');
        expect(json['is_completed'], isTrue);
        expect(json['created_at'], '2023-01-01T00:00:00.000');
        expect(json['updated_at'], '2023-01-02T00:00:00.000');
      });

      test('should handle very long title and description', () {
        // Arrange
        final longTitle = 'A' * 1000;
        final longDescription = 'B' * 2000;
        final taskModel = TaskModel(
          id: 'task-1',
          title: longTitle,
          description: longDescription,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.title, longTitle);
        expect(converted.description, longDescription);
      });

      test('should handle special characters in title and description', () {
        // Arrange
        const specialTitle = 'Task with special chars: '
            r'!@#$%^&*()_+-=[]{}|;:,.<>?';
        const specialDescription = 'Description with unicode: 你好世界 🌍';
        final taskModel = TaskModel(
          id: 'task-1',
          title: specialTitle,
          description: specialDescription,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.title, specialTitle);
        expect(converted.description, specialDescription);
      });

      test('should handle ISO8601 timestamp variations', () {
        // Arrange
        final timestamps = [
          '2023-01-01T00:00:00.000Z',
          '2023-01-01T00:00:00Z',
          '2023-01-01T00:00:00.123456Z',
        ];

        for (final timestamp in timestamps) {
          final json = {
            'id': 'task-1',
            'title': 'Test Task',
            'created_at': timestamp,
            'updated_at': timestamp,
          };

          // Act & Assert
          expect(() => TaskModel.fromJson(json), returnsNormally);
        }
      });

      test('should handle task with same createdAt and updatedAt', () {
        // Arrange
        final now = DateTime.now();
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: now,
          updatedAt: now,
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.createdAt, now);
        expect(converted.updatedAt, now);
      });

      test('should handle task with updatedAt before createdAt', () {
        // Arrange
        final createdAt = DateTime(2023, 1, 2);
        final updatedAt = DateTime(2023);
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        // Act
        final json = taskModel.toJson();
        final converted = TaskModel.fromJson(json);

        // Assert
        expect(converted.createdAt, createdAt);
        expect(converted.updatedAt, updatedAt);
      });

      test('should handle fromEntity with all fields', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          description: 'Test Description',
          isCompleted: true,
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final taskModel = TaskModel.fromEntity(task);

        // Assert
        expect(taskModel.id, task.id);
        expect(taskModel.title, task.title);
        expect(taskModel.description, task.description);
        expect(taskModel.isCompleted, task.isCompleted);
        expect(taskModel.createdAt, task.createdAt);
        expect(taskModel.updatedAt, task.updatedAt);
      });

      test('should handle fromEntity with null description', () {
        // Arrange
        final task = Task(
          id: 'task-1',
          title: 'Test Task',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final taskModel = TaskModel.fromEntity(task);

        // Assert
        expect(taskModel.description, isNull);
      });

      test('should handle toEntity returns same instance', () {
        // Arrange
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final entity = taskModel.toEntity();

        // Assert
        expect(entity, same(taskModel));
        expect(entity, isA<Task>());
      });

      test('should handle JSON with false is_completed explicitly', () {
        // Arrange
        final json = {
          'id': 'task-1',
          'title': 'Test Task',
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Act
        final taskModel = TaskModel.fromJson(json);

        // Assert
        expect(taskModel.isCompleted, isFalse);
      });

      test('should handle toJson with null description', () {
        // Arrange
        final taskModel = TaskModel(
          id: 'task-1',
          title: 'Test Task',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Act
        final json = taskModel.toJson();

        // Assert
        expect(json['description'], isNull);
      });
    });
  });
}
