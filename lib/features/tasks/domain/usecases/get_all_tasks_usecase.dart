import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';

/// Use case for getting all tasks
class GetAllTasksUseCase {
  /// Creates a [GetAllTasksUseCase] with the given [repository]
  GetAllTasksUseCase(this.repository);

  /// Tasks repository for getting all tasks
  final TasksRepository repository;

  /// Executes getting all tasks
  Future<Result<List<Task>>> call() async {
    return repository.getAllTasks();
  }
}
