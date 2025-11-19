import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
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
  });
}
