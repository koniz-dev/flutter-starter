import 'dart:math';

import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';

/// Use case for creating a task
class CreateTaskUseCase {
  /// Creates a [CreateTaskUseCase] with the given [repository]
  CreateTaskUseCase(this.repository);

  /// Tasks repository for creating tasks
  final TasksRepository repository;

  /// Monotonic counter making ids unique within a process, however fast
  /// tasks are created. A wall-clock timestamp alone collides whenever two
  /// tasks are created inside the same millisecond.
  static int _sequence = 0;

  /// Random suffix so ids minted by different processes (or after a restart
  /// that resets [_sequence]) cannot collide either.
  static final Random _random = Random();

  /// Generates a unique task id.
  static String generateId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final sequence = (_sequence++).toRadixString(36);
    final suffix = _random.nextInt(1 << 30).toRadixString(36);
    return '$micros-$sequence-$suffix';
  }

  /// Executes creating a task with [title] and optional [description]
  Future<Result<Task>> call({
    required String title,
    String? description,
  }) async {
    final now = DateTime.now();
    final task = Task(
      id: generateId(),
      title: title,
      createdAt: now,
      updatedAt: now,
      description: description,
    );
    return repository.createTask(task);
  }
}
