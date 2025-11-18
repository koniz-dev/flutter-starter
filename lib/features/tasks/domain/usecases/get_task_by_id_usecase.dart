import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';

/// Use case for getting a task by id
class GetTaskByIdUseCase {
  /// Creates a [GetTaskByIdUseCase] with the given [repository]
  GetTaskByIdUseCase(this.repository);

  /// Tasks repository for getting a task by id
  final TasksRepository repository;

  /// Executes getting a task by [id]
  Future<Result<Task?>> call(String id) async {
    return repository.getTaskById(id);
  }
}
