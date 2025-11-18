import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';

/// Use case for deleting a task
class DeleteTaskUseCase {
  /// Creates a [DeleteTaskUseCase] with the given [repository]
  DeleteTaskUseCase(this.repository);

  /// Tasks repository for deleting tasks
  final TasksRepository repository;

  /// Executes deleting a task by [id]
  Future<Result<void>> call(String id) async {
    return repository.deleteTask(id);
  }
}
