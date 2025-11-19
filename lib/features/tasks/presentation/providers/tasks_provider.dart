import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';

/// Tasks state
class TasksState {
  /// Creates a [TasksState] with the given [tasks], [isLoading], and [error]
  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
  });

  /// List of tasks
  final List<Task> tasks;

  /// Whether a task operation is in progress
  final bool isLoading;

  /// Error message if operation failed, null otherwise
  final String? error;

  /// Creates a copy of this state with the given fields replaced
  TasksState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Tasks provider (Riverpod 3.0 - using Notifier)
class TasksNotifier extends Notifier<TasksState> {
  @override
  TasksState build() {
    // Load tasks when provider is initialized
    // Use Future.microtask to ensure state is available before accessing it
    unawaited(Future.microtask(_loadTasks));
    return const TasksState();
  }

  /// Loads all tasks
  Future<void> _loadTasks() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);

    final getAllTasksUseCase = ref.read(getAllTasksUseCaseProvider);
    final result = await getAllTasksUseCase();

    if (!ref.mounted) return;
    
    result.when(
      success: (tasks) {
        if (!ref.mounted) return;
        state = state.copyWith(
          tasks: tasks,
          isLoading: false,
          clearError: true,
        );
      },
      failureCallback: (failure) {
        if (!ref.mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Refreshes the tasks list
  Future<void> refresh() async {
    await _loadTasks();
  }

  /// Creates a new task with [title] and optional [description]
  Future<void> createTask({
    required String title,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final createTaskUseCase = ref.read(createTaskUseCaseProvider);
    final result = await createTaskUseCase(
      title: title,
      description: description,
    );

    result.when(
      success: (_) {
        // Reload tasks to get updated list
        unawaited(_loadTasks());
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Updates an existing [task]
  Future<void> updateTask(Task task) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final updateTaskUseCase = ref.read(updateTaskUseCaseProvider);
    final result = await updateTaskUseCase(task);

    result.when(
      success: (_) {
        // Reload tasks to get updated list
        unawaited(_loadTasks());
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Deletes a task by [id]
  Future<void> deleteTask(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final deleteTaskUseCase = ref.read(deleteTaskUseCaseProvider);
    final result = await deleteTaskUseCase(id);

    result.when(
      success: (_) {
        // Reload tasks to get updated list
        unawaited(_loadTasks());
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }

  /// Toggles task completion status by [id]
  Future<void> toggleTaskCompletion(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final toggleTaskCompletionUseCase =
        ref.read(toggleTaskCompletionUseCaseProvider);
    final result = await toggleTaskCompletionUseCase(id);

    result.when(
      success: (_) {
        // Reload tasks to get updated list
        unawaited(_loadTasks());
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }
}

/// Provider for TasksNotifier (Riverpod 3.0 - using NotifierProvider)
final tasksNotifierProvider =
    NotifierProvider<TasksNotifier, TasksState>(TasksNotifier.new);
