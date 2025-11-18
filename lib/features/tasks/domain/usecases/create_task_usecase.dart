import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';

/// Use case for creating a task
class CreateTaskUseCase {
  /// Creates a [CreateTaskUseCase] with the given [repository]
  CreateTaskUseCase(this.repository);

  /// Tasks repository for creating tasks
  final TasksRepository repository;

  /// Executes creating a task with [title] and optional [description]
  Future<Result<Task>> call({
    required String title,
    String? description,
  }) async {
    final now = DateTime.now();
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
      updatedAt: now,
      description: description,
    );
    return repository.createTask(task);
  }
}
