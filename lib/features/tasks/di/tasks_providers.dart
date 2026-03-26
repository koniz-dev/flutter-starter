import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/repositories/tasks_repository_impl.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/create_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/delete_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/toggle_task_completion_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/update_task_usecase.dart';

// ============================================================================
// Tasks Data Source Providers
// ============================================================================

/// Provider for [TasksLocalDataSource] instance
final tasksLocalDataSourceProvider = Provider<TasksLocalDataSource>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return TasksLocalDataSourceImpl(storageService: storageService);
});

// ============================================================================
// Tasks Repository Provider
// ============================================================================

/// Provider for [TasksRepository] instance
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final localDataSource = ref.watch(tasksLocalDataSourceProvider);
  return TasksRepositoryImpl(localDataSource: localDataSource);
});

// ============================================================================
// Tasks Use Case Providers
// ============================================================================

/// Provider for [GetAllTasksUseCase] instance
final getAllTasksUseCaseProvider = Provider<GetAllTasksUseCase>((ref) {
  final repository = ref.watch<TasksRepository>(tasksRepositoryProvider);
  return GetAllTasksUseCase(repository);
});

/// Provider for [GetTaskByIdUseCase] instance
final getTaskByIdUseCaseProvider = Provider<GetTaskByIdUseCase>((ref) {
  final repository = ref.watch<TasksRepository>(tasksRepositoryProvider);
  return GetTaskByIdUseCase(repository);
});

/// Provider for [CreateTaskUseCase] instance
final createTaskUseCaseProvider = Provider<CreateTaskUseCase>((ref) {
  final repository = ref.watch<TasksRepository>(tasksRepositoryProvider);
  return CreateTaskUseCase(repository);
});

/// Provider for [UpdateTaskUseCase] instance
final updateTaskUseCaseProvider = Provider<UpdateTaskUseCase>((ref) {
  final repository = ref.watch<TasksRepository>(tasksRepositoryProvider);
  return UpdateTaskUseCase(repository);
});

/// Provider for [DeleteTaskUseCase] instance
final deleteTaskUseCaseProvider = Provider<DeleteTaskUseCase>((ref) {
  final repository = ref.watch<TasksRepository>(tasksRepositoryProvider);
  return DeleteTaskUseCase(repository);
});

/// Provider for [ToggleTaskCompletionUseCase] instance
final toggleTaskCompletionUseCaseProvider =
    Provider<ToggleTaskCompletionUseCase>((ref) {
      final repository = ref.watch<TasksRepository>(tasksRepositoryProvider);
      return ToggleTaskCompletionUseCase(repository);
    });
