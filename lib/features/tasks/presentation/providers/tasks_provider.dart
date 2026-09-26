import 'dart:async';

import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tasks_provider.g.dart';

/// Tasks state
class TasksState {
  /// Creates a [TasksState] with the given [tasks], [isLoading], [error] and
  /// [pendingTaskIds]
  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.pendingTaskIds = const {},
  });

  /// List of tasks
  final List<Task> tasks;

  /// Whether a task operation is in progress
  final bool isLoading;

  /// Error message if operation failed, null otherwise
  final String? error;

  /// Ids of tasks with a mutation currently in flight.
  ///
  /// The list screen disables the per-task controls for these ids so a second
  /// tap cannot queue a second mutation against a stale value.
  final Set<String> pendingTaskIds;

  /// Creates a copy of this state with the given fields replaced
  TasksState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? pendingTaskIds,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      pendingTaskIds: pendingTaskIds ?? this.pendingTaskIds,
    );
  }
}

/// Tasks provider (Riverpod Generator).
@Riverpod(keepAlive: true)
class TasksNotifier extends _$TasksNotifier {
  @override
  TasksState build() {
    // Load tasks when provider is initialized
    // Use Future.microtask to ensure state is available before accessing it
    unawaited(Future.microtask(_loadTasks));
    return const TasksState();
  }

  /// Sequence number of the most recently started load.
  ///
  /// Reloads can overlap, and they do not necessarily complete in the order
  /// they were issued. Only the newest load is allowed to write its snapshot
  /// to state, so a slow older load cannot land after a newer one and
  /// resurrect stale data.
  int _loadToken = 0;

  /// Loads all tasks
  Future<void> _loadTasks() async {
    if (!ref.mounted) return;
    final token = ++_loadToken;
    state = state.copyWith(isLoading: true, clearError: true);

    final getAllTasksUseCase = ref.read(getAllTasksUseCaseProvider);
    final result = await getAllTasksUseCase();

    // Superseded by a newer load, or the provider is gone: drop the snapshot.
    if (!ref.mounted || token != _loadToken) return;

    result.when(
      success: (tasks) {
        state = state.copyWith(
          tasks: tasks,
          isLoading: false,
          clearError: true,
        );
      },
      failureCallback: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  /// Refreshes the tasks list
  Future<void> refresh() async {
    await _loadTasks();
  }

  /// Loads the single task with [id] through this notifier.
  ///
  /// The detail screen needs one task rather than the whole list, but it must
  /// not reach past the notifier into `getTaskByIdUseCaseProvider`: that is the
  /// presentation boundary `tasks_list_screen.dart` already respects, and two
  /// screens in one slice answering it differently is what
  /// koniz-dev/flutter-starter#180 removed. The result is returned rather than
  /// written to [state] because a single opened task is a per-screen concern -
  /// folding it into the shared snapshot would make every list rebuild on it.
  Future<Result<Task?>> taskById(String id) {
    final getTaskByIdUseCase = ref.read(getTaskByIdUseCaseProvider);
    return getTaskByIdUseCase(id);
  }

  /// Creates a new task with [title] and optional [description]
  Future<void> createTask({required String title, String? description}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final createTaskUseCase = ref.read(createTaskUseCaseProvider);
    final result = await createTaskUseCase(
      title: title,
      description: description,
    );

    if (!ref.mounted) return;

    await result.when(
      // Await the reload so the caller only resumes once `state.tasks`
      // reflects the mutation.
      success: (_) => _loadTasks(),
      failureCallback: (failure) async {
        // Keep the already-loaded tasks: a failed mutation reports an error,
        // it does not empty the list.
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  /// Updates an existing [task]
  Future<void> updateTask(Task task) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final updateTaskUseCase = ref.read(updateTaskUseCaseProvider);
    final result = await updateTaskUseCase(task);

    if (!ref.mounted) return;

    await result.when(
      success: (_) => _loadTasks(),
      failureCallback: (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  /// Deletes a task by [id]
  Future<void> deleteTask(String id) async {
    if (state.pendingTaskIds.contains(id)) return;
    state = _withPending(id).copyWith(isLoading: true, clearError: true);

    final deleteTaskUseCase = ref.read(deleteTaskUseCaseProvider);
    final result = await deleteTaskUseCase(id);

    if (!ref.mounted) return;
    state = _withoutPending(id);

    await result.when(
      success: (_) => _loadTasks(),
      failureCallback: (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  /// Toggles task completion status by [id]
  Future<void> toggleTaskCompletion(String id) async {
    // A toggle is already in flight for this task: ignore the repeat tap
    // instead of computing a second flip from the same stale value.
    if (state.pendingTaskIds.contains(id)) return;
    state = _withPending(id).copyWith(isLoading: true, clearError: true);

    final toggleTaskCompletionUseCase = ref.read(
      toggleTaskCompletionUseCaseProvider,
    );
    final result = await toggleTaskCompletionUseCase(id);

    if (!ref.mounted) return;
    state = _withoutPending(id);

    await result.when(
      success: (_) => _loadTasks(),
      failureCallback: (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  TasksState _withPending(String id) =>
      state.copyWith(pendingTaskIds: {...state.pendingTaskIds, id});

  TasksState _withoutPending(String id) => state.copyWith(
    pendingTaskIds: {...state.pendingTaskIds}..remove(id),
  );
}

/// Alias for [tasksProvider] (older imports use `tasksNotifierProvider`).
const TasksNotifierProvider tasksNotifierProvider = tasksProvider;
