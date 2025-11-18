import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';

/// Implementation of tasks repository
class TasksRepositoryImpl implements TasksRepository {
  /// Creates a [TasksRepositoryImpl] with the given [localDataSource]
  TasksRepositoryImpl({
    required this.localDataSource,
  });

  /// Local data source for tasks
  final TasksLocalDataSource localDataSource;

  @override
  Future<Result<List<Task>>> getAllTasks() async {
    try {
      final tasks = await localDataSource.getAllTasks();
      return Success(tasks.map((model) => model.toEntity()).toList());
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  @override
  Future<Result<Task?>> getTaskById(String id) async {
    try {
      final task = await localDataSource.getTaskById(id);
      return Success(task?.toEntity());
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  @override
  Future<Result<Task>> createTask(Task task) async {
    try {
      final taskModel = TaskModel.fromEntity(task);
      await localDataSource.saveTask(taskModel);
      return Success(task);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  @override
  Future<Result<Task>> updateTask(Task task) async {
    try {
      final taskModel = TaskModel.fromEntity(task);
      await localDataSource.saveTask(taskModel);
      return Success(task);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  @override
  Future<Result<void>> deleteTask(String id) async {
    try {
      await localDataSource.deleteTask(id);
      return const Success(null);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  @override
  Future<Result<void>> deleteCompletedTasks() async {
    try {
      final tasks = await localDataSource.getAllTasks();
      final incompleteTasks = tasks.where((task) => !task.isCompleted).toList();
      await localDataSource.saveTasks(incompleteTasks);
      return const Success(null);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  @override
  Future<Result<Task>> toggleTaskCompletion(String id) async {
    try {
      final taskModel = await localDataSource.getTaskById(id);
      if (taskModel == null) {
        return const ResultFailure(
          CacheFailure('Task not found'),
        );
      }

      final updatedTaskModel = TaskModel(
        id: taskModel.id,
        title: taskModel.title,
        description: taskModel.description,
        isCompleted: !taskModel.isCompleted,
        createdAt: taskModel.createdAt,
        updatedAt: DateTime.now(),
      );
      await localDataSource.saveTask(updatedTaskModel);
      return Success(updatedTaskModel.toEntity());
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
}
