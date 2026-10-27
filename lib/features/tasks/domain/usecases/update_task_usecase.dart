import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/task_title_rule.dart';

/// Use case for updating a task
class UpdateTaskUseCase {
  /// Creates an [UpdateTaskUseCase] with the given [repository]
  UpdateTaskUseCase(this.repository);

  /// Tasks repository for updating tasks
  final TasksRepository repository;

  /// Executes updating a task.
  ///
  /// A blank title returns a [ValidationFailure] without reaching the
  /// repository.
  Future<Result<Task>> call(Task task) async {
    final invalid = validateTaskTitle(task.title);
    if (invalid != null) return ResultFailure(invalid);
    final updatedTask = task.touch();
    return await repository.updateTask(updatedTask);
  }
}
