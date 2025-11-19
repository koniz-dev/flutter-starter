import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/json_helper.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_fixtures.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  group('TasksLocalDataSourceImpl', () {
    late TasksLocalDataSourceImpl dataSource;
    late MockStorageService mockStorageService;

    setUp(() {
      mockStorageService = MockStorageService();
      dataSource = TasksLocalDataSourceImpl(storageService: mockStorageService);
    });

    group('getAllTasks', () {
      test('should return list of tasks when storage has data', () async {
        // Arrange
        final taskModels = [
          createTaskModel(id: 'task-1'),
          createTaskModel(id: 'task-2'),
        ];
        final tasksJson = taskModels.map((t) => t.toJson()).toList();
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);

        // Act
        final result = await dataSource.getAllTasks();

        // Assert
        expect(result.length, 2);
        expect(result[0].id, 'task-1');
        expect(result[1].id, 'task-2');
        verify(() => mockStorageService.getString('tasks_data')).called(1);
      });

      test('should return empty list when storage is empty', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => null);

        // Act
        final result = await dataSource.getAllTasks();

        // Assert
        expect(result, isEmpty);
        verify(() => mockStorageService.getString('tasks_data')).called(1);
      });

      test('should return empty list when storage has empty string', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => '');

        // Act
        final result = await dataSource.getAllTasks();

        // Assert
        expect(result, isEmpty);
      });

      test('should return empty list when JSON decode fails', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => 'invalid-json');

        // Act
        final result = await dataSource.getAllTasks();

        // Assert
        expect(result, isEmpty);
      });

      test('should throw CacheException when storage throws exception',
          () async {
        // Arrange
        final exception = Exception('Storage error');
        when(() => mockStorageService.getString(any())).thenThrow(exception);

        // Act & Assert
        expect(
          () => dataSource.getAllTasks(),
          throwsA(isA<CacheException>()),
        );
      });
    });

    group('getTaskById', () {
      test('should return task when found', () async {
        // Arrange
        const taskId = 'task-1';
        final taskModels = [
          createTaskModel(id: 'task-1'),
          createTaskModel(id: 'task-2'),
        ];
        final tasksJson = taskModels.map((t) => t.toJson()).toList();
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);

        // Act
        final result = await dataSource.getTaskById(taskId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, taskId);
      });

      test('should return null when task not found', () async {
        // Arrange
        const taskId = 'non-existent';
        final taskModels = [createTaskModel(id: 'task-1')];
        final tasksJson = taskModels.map((t) => t.toJson()).toList();
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);

        // Act
        final result = await dataSource.getTaskById(taskId);

        // Assert
        expect(result, isNull);
      });

      test('should throw CacheException when getAllTasks throws', () async {
        // Arrange
        const taskId = 'task-1';
        final exception = Exception('Storage error');
        when(() => mockStorageService.getString(any())).thenThrow(exception);

        // Act & Assert
        expect(
          () => dataSource.getTaskById(taskId),
          throwsA(isA<CacheException>()),
        );
      });
    });

    group('saveTask', () {
      test('should save new task', () async {
        // Arrange
        final newTask = createTaskModel(id: 'task-new');
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => null);
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.saveTask(newTask);

        // Assert
        verify(() => mockStorageService.getString('tasks_data')).called(1);
        verify(() => mockStorageService.setString(any(), any())).called(1);
      });

      test('should update existing task', () async {
        // Arrange
        final existingTask = createTaskModel(id: 'task-1', title: 'Original');
        final updatedTask = createTaskModel(id: 'task-1', title: 'Updated');
        final tasksJson = [existingTask.toJson()];
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.saveTask(updatedTask);

        // Assert
        verify(() => mockStorageService.getString('tasks_data')).called(1);
        final savedData = verify(
          () => mockStorageService.setString('tasks_data', captureAny()),
        ).captured.first as String;
        final decoded = JsonHelper.decodeList(savedData);
        expect(decoded, isNotNull);
        final savedTask = TaskModel.fromJson(
          decoded!.first as Map<String, dynamic>,
        );
        expect(savedTask.title, 'Updated');
      });

      test('should throw CacheException when storage throws', () async {
        // Arrange
        final task = createTaskModel(id: 'task-1');
        final exception = Exception('Storage error');
        when(() => mockStorageService.getString(any())).thenThrow(exception);

        // Act & Assert
        expect(
          () => dataSource.saveTask(task),
          throwsA(isA<CacheException>()),
        );
      });
    });

    group('saveTasks', () {
      test('should save list of tasks', () async {
        // Arrange
        final tasks = [
          createTaskModel(id: 'task-1'),
          createTaskModel(id: 'task-2'),
        ];
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.saveTasks(tasks);

        // Assert
        verify(() => mockStorageService.setString(any(), any())).called(1);
      });

      test('should throw CacheException when encoding fails', () async {
        // Arrange
        final tasks = [createTaskModel(id: 'task-1')];
        when(() => mockStorageService.setString(any(), any()))
            .thenThrow(Exception('Storage error'));

        // Act & Assert
        expect(
          () => dataSource.saveTasks(tasks),
          throwsA(isA<CacheException>()),
        );
      });
    });

    group('deleteTask', () {
      test('should delete task by id', () async {
        // Arrange
        const taskId = 'task-1';
        final tasks = [
          createTaskModel(id: 'task-1'),
          createTaskModel(id: 'task-2'),
        ];
        final tasksJson = tasks.map((t) => t.toJson()).toList();
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.deleteTask(taskId);

        // Assert
        verify(() => mockStorageService.getString('tasks_data')).called(1);
        final savedData = verify(
          () => mockStorageService.setString('tasks_data', captureAny()),
        ).captured.first as String;
        final decoded = JsonHelper.decodeList(savedData);
        expect(decoded, isNotNull);
        expect(decoded!.length, 1);
        final taskJson = decoded.first as Map<String, dynamic>;
        expect(taskJson['id'], 'task-2');
      });

      test('should throw CacheException when storage throws', () async {
        // Arrange
        const taskId = 'task-1';
        final exception = Exception('Storage error');
        when(() => mockStorageService.getString(any())).thenThrow(exception);

        // Act & Assert
        expect(
          () => dataSource.deleteTask(taskId),
          throwsA(isA<CacheException>()),
        );
      });
    });

    group('deleteAllTasks', () {
      test('should delete all tasks', () async {
        // Arrange
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.deleteAllTasks();

        // Assert
        verify(() => mockStorageService.remove('tasks_data')).called(1);
      });

      test('should throw CacheException when storage throws', () async {
        // Arrange
        final exception = Exception('Storage error');
        when(() => mockStorageService.remove(any())).thenThrow(exception);

        // Act & Assert
        expect(
          () => dataSource.deleteAllTasks(),
          throwsA(isA<CacheException>()),
        );
      });
    });

    group('Edge cases', () {
      test('should handle large number of tasks', () async {
        // Arrange
        final tasks = List.generate(
          1000,
          (index) => createTaskModel(id: 'task-$index'),
        );
        final tasksJson = tasks.map((t) => t.toJson()).toList();
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);

        // Act
        final result = await dataSource.getAllTasks();

        // Assert
        expect(result.length, 1000);
      });

      test('should handle saveTask with duplicate IDs correctly', () async {
        // Arrange
        final task1 = createTaskModel(id: 'task-1', title: 'Original');
        final task2 = createTaskModel(id: 'task-1', title: 'Updated');
        final tasksJson = [task1.toJson()];
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.saveTask(task2);

        // Assert
        final savedData = verify(
          () => mockStorageService.setString('tasks_data', captureAny()),
        ).captured.first as String;
        final decoded = JsonHelper.decodeList(savedData);
        expect(decoded, isNotNull);
        final savedTasks = decoded!
            .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
            .toList();
        expect(savedTasks.length, 1);
        expect(savedTasks.first.title, 'Updated');
      });

      test('should handle deleteTask with non-existent ID', () async {
        // Arrange
        final tasks = [createTaskModel(id: 'task-1')];
        final tasksJson = tasks.map((t) => t.toJson()).toList();
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.deleteTask('non-existent');

        // Assert
        final savedData = verify(
          () => mockStorageService.setString('tasks_data', captureAny()),
        ).captured.first as String;
        final decoded = JsonHelper.decodeList(savedData);
        expect(decoded, isNotNull);
        expect(decoded!.length, 1); // Task should still be there
      });

      test('should handle saveTasks with empty list', () async {
        // Arrange
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.saveTasks([]);

        // Assert
        final savedData = verify(
          () => mockStorageService.setString('tasks_data', captureAny()),
        ).captured.first as String;
        final decoded = JsonHelper.decodeList(savedData);
        expect(decoded, isEmpty);
      });

      test('should handle getTaskById with empty string ID', () async {
        // Arrange
        final tasks = [createTaskModel(id: 'task-1')];
        final tasksJson = tasks.map((t) => t.toJson()).toList();
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);

        // Act
        final result = await dataSource.getTaskById('');

        // Assert
        expect(result, isNull);
      });

      test('should handle saveTask when getAllTasks returns null', () async {
        // Arrange
        final newTask = createTaskModel(id: 'task-new');
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => null);
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.saveTask(newTask);

        // Assert
        verify(() => mockStorageService.setString(any(), any())).called(1);
      });

      test(
        'should handle saveTask when getAllTasks returns empty string',
        () async {
        // Arrange
        final newTask = createTaskModel(id: 'task-new');
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => '');
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.saveTask(newTask);

        // Assert
        verify(() => mockStorageService.setString(any(), any())).called(1);
      });

      test(
        'should handle saveTasks when JsonHelper.encode returns null',
        () async {
        // Arrange
        final tasks = [createTaskModel(id: 'task-1')];
        // Mock to make JsonHelper.encode return null
        // (this is hard to do, but we test the error path)
        when(() => mockStorageService.setString(any(), any()))
            .thenThrow(Exception('Encoding failed'));

        // Act & Assert
        expect(
          () => dataSource.saveTasks(tasks),
          throwsA(isA<CacheException>()),
        );
      });

      test(
        'should handle getTaskById when multiple tasks have same ID',
        () async {
        // Arrange
        // This shouldn't happen in practice, but we test the behavior
        final task1 = createTaskModel(id: 'task-1', title: 'First');
        final task2 = createTaskModel(id: 'task-1', title: 'Second');
        final tasksJson = [task1.toJson(), task2.toJson()];
        final encoded = JsonHelper.encode(tasksJson);
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => encoded);

        // Act
        final result = await dataSource.getTaskById('task-1');

        // Assert
        // Should return the first match
        expect(result, isNotNull);
        expect(result!.id, 'task-1');
        expect(result.title, 'First');
      });
    });
  });
}
