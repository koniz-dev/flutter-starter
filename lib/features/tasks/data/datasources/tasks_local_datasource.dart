import 'dart:async';

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

  /// Atomically read the stored tasks, apply [transform], and write the
  /// result back.
  ///
  /// The read-modify-write runs to completion before any other mutation on
  /// this data source starts, so concurrent callers cannot overwrite each
  /// other's changes. Returns the list that was written.
  Future<List<TaskModel>> mutateTasks(
    List<TaskModel> Function(List<TaskModel> current) transform,
  );
}

/// Implementation of local data source for tasks
class TasksLocalDataSourceImpl implements TasksLocalDataSource {
  /// Creates a [TasksLocalDataSourceImpl] with the given [storageService]
  TasksLocalDataSourceImpl({required this.storageService});

  /// Storage service for persisting tasks
  final StorageService storageService;

  /// Storage key for tasks list
  static const String _tasksKey = 'tasks_data';

  /// Tail of the mutation queue.
  ///
  /// Every mutation chains onto this future, which serialises the
  /// read-modify-write cycles that share the single `tasks_data` blob.
  /// Errors are absorbed here so one failed mutation does not poison the
  /// queue for the next one.
  Future<void> _mutations = Future<void>.value();

  /// Runs [action] only after every previously queued mutation has settled.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _mutations.then((_) => action());
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<List<TaskModel>> getAllTasks() async {
    try {
      return await _readTasks();
    } on Exception catch (e) {
      throw CacheException('Failed to get tasks: $e');
    }
  }

  @override
  Future<TaskModel?> getTaskById(String id) async {
    try {
      final tasks = await _readTasks();
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
      await mutateTasks((current) {
        final tasks = [...current];
        final existingIndex = tasks.indexWhere((t) => t.id == task.id);
        if (existingIndex >= 0) {
          // Update existing task
          tasks[existingIndex] = task;
        } else {
          // Add new task
          tasks.add(task);
        }
        return tasks;
      });
    } on Exception catch (e) {
      throw CacheException('Failed to save task: $e');
    }
  }

  @override
  Future<void> saveTasks(List<TaskModel> tasks) async {
    try {
      await _serialized(() => _writeTasks(tasks));
    } on Exception catch (e) {
      throw CacheException('Failed to save tasks: $e');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      await mutateTasks(
        (current) => current.where((task) => task.id != id).toList(),
      );
    } on Exception catch (e) {
      throw CacheException('Failed to delete task: $e');
    }
  }

  @override
  Future<void> deleteAllTasks() async {
    try {
      await _serialized(() => storageService.remove(_tasksKey));
    } on Exception catch (e) {
      throw CacheException('Failed to delete all tasks: $e');
    }
  }

  @override
  Future<List<TaskModel>> mutateTasks(
    List<TaskModel> Function(List<TaskModel> current) transform,
  ) {
    return _serialized(() async {
      final next = transform(await _readTasks());
      await _writeTasks(next);
      return next;
    });
  }

  Future<List<TaskModel>> _readTasks() async {
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
  }

  Future<void> _writeTasks(List<TaskModel> tasks) async {
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    final encoded = JsonHelper.encode(tasksJson);
    if (encoded == null) {
      throw const CacheException('Failed to encode tasks data');
    }
    await storageService.setString(_tasksKey, encoded);
  }
}
