import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/json_helper.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';

/// Local data source for tasks
abstract class TasksLocalDataSource {
  /// Get all tasks from local storage
  Future<List<TaskModel>> getAllTasks();

  /// Get a task by [id] from local storage
  Future<TaskModel?> getTaskById(String id);

  /// Save a task to local storage
  Future<void> saveTask(TaskModel task);

  /// Save multiple tasks to local storage
  Future<void> saveTasks(List<TaskModel> tasks);

  /// Delete a task by [id] from local storage
  Future<void> deleteTask(String id);

  /// Delete all tasks from local storage
  Future<void> deleteAllTasks();
}

/// Implementation of local data source for tasks
class TasksLocalDataSourceImpl implements TasksLocalDataSource {
  /// Creates a [TasksLocalDataSourceImpl] with the given [storageService]
  TasksLocalDataSourceImpl({
    required this.storageService,
  });

  /// Storage service for persisting tasks
  final StorageService storageService;

  /// Storage key for tasks list
  static const String _tasksKey = 'tasks_data';

  @override
  Future<List<TaskModel>> getAllTasks() async {
    try {
      final tasksJson = await storageService.getString(_tasksKey);
      if (tasksJson == null || tasksJson.isEmpty) {
        return [];
      }

      final tasksList = JsonHelper.decodeList(tasksJson);
      if (tasksList == null) {
        return [];
      }

      return tasksList
          .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on Exception catch (e) {
      throw CacheException('Failed to get tasks: $e');
    }
  }

  @override
  Future<TaskModel?> getTaskById(String id) async {
    try {
      final tasks = await getAllTasks();
      for (final task in tasks) {
        if (task.id == id) {
          return task;
        }
      }
      return null;
    } on Exception catch (e) {
      throw CacheException('Failed to get task by id: $e');
    }
  }

  @override
  Future<void> saveTask(TaskModel task) async {
    try {
      final tasks = await getAllTasks();
      final existingIndex = tasks.indexWhere((t) => t.id == task.id);

      if (existingIndex >= 0) {
        // Update existing task
        tasks[existingIndex] = task;
      } else {
        // Add new task
        tasks.add(task);
      }

      await saveTasks(tasks);
    } on Exception catch (e) {
      throw CacheException('Failed to save task: $e');
    }
  }

  @override
  Future<void> saveTasks(List<TaskModel> tasks) async {
    try {
      final tasksJson = tasks.map((task) => task.toJson()).toList();
      final encoded = JsonHelper.encode(tasksJson);
      if (encoded == null) {
        throw const CacheException('Failed to encode tasks data');
      }
      await storageService.setString(_tasksKey, encoded);
    } on Exception catch (e) {
      throw CacheException('Failed to save tasks: $e');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      final tasks = await getAllTasks();
      tasks.removeWhere((task) => task.id == id);
      await saveTasks(tasks);
    } on Exception catch (e) {
      throw CacheException('Failed to delete task: $e');
    }
  }

  @override
  Future<void> deleteAllTasks() async {
    try {
      await storageService.remove(_tasksKey);
    } on Exception catch (e) {
      throw CacheException('Failed to delete all tasks: $e');
    }
  }
}
