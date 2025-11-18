import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';

/// Tasks repository interface (domain layer)
abstract class TasksRepository {
  /// Get all tasks
  Future<Result<List<Task>>> getAllTasks();

  /// Get a task by [id]
  Future<Result<Task?>> getTaskById(String id);

  /// Create a new task
  Future<Result<Task>> createTask(Task task);

  /// Update an existing task
  Future<Result<Task>> updateTask(Task task);

  /// Delete a task by [id]
  Future<Result<void>> deleteTask(String id);

  /// Delete all completed tasks
  Future<Result<void>> deleteCompletedTasks();

  /// Toggle task completion status
  Future<Result<Task>> toggleTaskCompletion(String id);
}
