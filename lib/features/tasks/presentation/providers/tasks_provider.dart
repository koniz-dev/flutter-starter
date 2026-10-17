import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/session/session_providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tasks_provider.g.dart';

/// Tasks state
class TasksState {
  /// Creates a [TasksState] with the given [tasks], [isLoading], [error],
  /// [failure] and [pendingTaskIds]
  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.failure,
    this.pendingTaskIds = const {},
  });

  /// List of tasks
  final List<Task> tasks;

  /// Whether a task operation is in progress
  final bool isLoading;

  /// Error message if operation failed, null otherwise.
  ///
  /// This is [Failure.message]: English text built for logs. Screens render
  /// [failure] through `localizedMessage` instead
  /// (koniz-dev/flutter-starter#415).
  final String? error;

  /// The failure behind [error], kept so a screen can show it in the user's
  /// language.
  final Failure? failure;

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
    Failure? failure,
    bool clearError = false,
    Set<String>? pendingTaskIds,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      failure: clearError ? null : (failure ?? this.failure),
      pendingTaskIds: pendingTaskIds ?? this.pendingTaskIds,
    );
  }
}

/// Wipes the tasks of the previous user whenever the session changes.
///
/// Tasks are stored device-wide under one `tasks_data` key, not per user, so
/// the slice deletes them when a session ends or is replaced - logout, forced
/// logout, login, register - rather than scoping the key: scoping would need
/// the user id, and features may not import the auth slice that owns it
/// (koniz-dev/flutter-starter#353). [sessionEpochProvider] is the signal that
/// crosses that boundary.
///
/// The stored blob is deleted first and [tasksProvider] is invalidated only
/// once that has finished. Reads are not queued behind the delete, so
/// invalidating first would let the rebuilt notifier reload the previous
/// user's tasks; invalidating also drops a load that was still in flight for
/// the old session.
///
/// Read once at startup by the tasks routes, which the app router builds
/// eagerly, so the listener exists even if the tasks screen was never opened
/// during the session that is ending.
///
/// A failed delete must not hand the previous user's tasks to the next one,
/// so the wipe falls back, and as a last resort holds the list empty - see
/// [TasksSessionWipe] (koniz-dev/flutter-starter#458).
final tasksSessionResetProvider = Provider<void>((ref) {
  ref.listen<int>(sessionEpochProvider, (_, _) {
    final wipe = ref.read(tasksSessionWipeProvider);
    unawaited(
      wipe.run().whenComplete(() {
        if (ref.mounted) ref.invalidate(tasksProvider);
      }),
    );
  });
});

/// Removes the stored tasks of a session that has ended, and remembers when it
/// could not (koniz-dev/flutter-starter#458).
///
/// [run] never throws. In order:
///
/// 1. `deleteAllTasks()` removes the `tasks_data` key.
/// 2. If that fails, the key is overwritten with an empty list instead
///    (`saveTasks([])`): a different storage call, so a failing `remove` does
///    not doom it.
/// 3. If that fails too, [pending] stays true, and [TasksNotifier] holds the
///    list empty instead of loading - the blob may still be the previous
///    user's - retrying [run] on each load until a wipe succeeds.
///
/// Every failure is logged; none is dropped into the zone's uncaught-error
/// handler, which is where the bare `deleteAllTasks()` future used to send it.
class TasksSessionWipe {
  /// Creates a wipe over a tasks data source that reports failures to a
  /// logger.
  TasksSessionWipe(this._dataSource, this._logger);

  final TasksLocalDataSource _dataSource;
  final LoggingService _logger;

  /// Whether the last [run] failed to clear the stored tasks either way.
  bool get pending => _pending;
  bool _pending = false;

  /// Clears the stored tasks; see the class doc for the fallbacks.
  Future<void> run() async {
    try {
      await _dataSource.deleteAllTasks();
      _pending = false;
      return;
    } on Object catch (error, stackTrace) {
      _logger.error(
        "Tasks: could not delete the previous session's tasks; overwriting "
        'them with an empty list instead',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await _dataSource.saveTasks(const []);
      _pending = false;
    } on Object catch (error, stackTrace) {
      _pending = true;
      _logger.error(
        "Tasks: could not overwrite the previous session's tasks either; "
        'holding the task list empty until a wipe succeeds',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// The app's single [TasksSessionWipe].
final tasksSessionWipeProvider = Provider<TasksSessionWipe>(
  (ref) => TasksSessionWipe(
    ref.watch(tasksLocalDataSourceProvider),
    ref.watch(loggingServiceProvider),
  ),
);

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

    // The previous session's tasks could not be wiped: what is stored may be
    // theirs, so retry the wipe and load nothing until it succeeds
    // (koniz-dev/flutter-starter#458).
    final wipe = ref.read(tasksSessionWipeProvider);
    if (wipe.pending) {
      await wipe.run();
      if (!ref.mounted || token != _loadToken) return;
      if (wipe.pending) {
        state = state.copyWith(
          tasks: const [],
          isLoading: false,
          clearError: true,
        );
        return;
      }
    }

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
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
          failure: failure,
        );
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

  /// Creates a new task with [title] and optional [description].
  ///
  /// Returns the use case's result so a caller can tell a failed save from a
  /// successful one; the failure is also recorded in `state.error`
  /// (koniz-dev/flutter-starter#346).
  Future<Result<Task>> createTask({
    required String title,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final createTaskUseCase = ref.read(createTaskUseCaseProvider);
    final result = await createTaskUseCase(
      title: title,
      description: description,
    );

    if (!ref.mounted) return result;

    await result.when(
      // Await the reload so the caller only resumes once `state.tasks`
      // reflects the mutation.
      success: (_) => _loadTasks(),
      failureCallback: (failure) async {
        // Keep the already-loaded tasks: a failed mutation reports an error,
        // it does not empty the list.
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
          failure: failure,
        );
      },
    );
    return result;
  }

  /// Updates an existing [task].
  ///
  /// Returns the use case's result, as [createTask] does.
  Future<Result<Task>> updateTask(Task task) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final updateTaskUseCase = ref.read(updateTaskUseCaseProvider);
    final result = await updateTaskUseCase(task);

    if (!ref.mounted) return result;

    await result.when(
      success: (_) => _loadTasks(),
      failureCallback: (failure) async {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
          failure: failure,
        );
      },
    );
    return result;
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
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
          failure: failure,
        );
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
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
          failure: failure,
        );
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
