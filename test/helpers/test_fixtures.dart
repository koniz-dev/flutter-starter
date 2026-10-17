import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';

/// Test fixtures for creating test data
///
/// These fixtures provide reusable test data that can be used across tests.
/// They follow the factory pattern and can be customized with optional
/// parameters.

// ============================================================================
// User Fixtures
// ============================================================================

/// Creates a test User entity
///
/// Default values:
/// - id: 'test-user-id'
/// - email: 'test@example.com'
/// - name: 'Test User'
/// - avatarUrl: null
User createUser({
  String id = 'test-user-id',
  String email = 'test@example.com',
  String? name,
  String? avatarUrl,
}) {
  return User(
    id: id,
    email: email,
    name: name ?? 'Test User',
    avatarUrl: avatarUrl,
  );
}

/// Creates a test UserModel
///
/// Default values match createUser() for consistency.
UserModel createUserModel({
  String id = 'test-user-id',
  String email = 'test@example.com',
  String? name,
  String? avatarUrl,
}) {
  return UserModel(
    id: id,
    email: email,
    name: name ?? 'Test User',
    avatarUrl: avatarUrl,
  );
}

// ============================================================================
// Auth Response Fixtures
// ============================================================================

/// Creates a test AuthResponseModel
///
/// Default values:
/// - user: test UserModel
/// - token: 'test-access-token'
/// - refreshToken: 'test-refresh-token'
AuthResponseModel createAuthResponse({
  UserModel? user,
  String token = 'test-access-token',
  String? refreshToken,
}) {
  return AuthResponseModel(
    user: user ?? createUserModel(),
    token: token,
    refreshToken: refreshToken ?? 'test-refresh-token',
  );
}

// ============================================================================
// Exception Fixtures
// ============================================================================

/// Creates a test ServerException
///
/// Default values:
/// - message: 'Server error'
/// - statusCode: 500
/// - code: 'SERVER_ERROR'
ServerException createServerException({
  String message = 'Server error',
  int? statusCode,
  String? code,
}) {
  return ServerException(
    message,
    statusCode: statusCode ?? 500,
    code: code ?? 'SERVER_ERROR',
  );
}

/// Creates a test CacheException
///
/// Default values:
/// - message: 'Cache error'
/// - code: 'CACHE_ERROR'
CacheException createCacheException({
  String message = 'Cache error',
  String? code,
}) {
  return CacheException(message, code: code ?? 'CACHE_ERROR');
}

// ============================================================================
// Failure Fixtures
// ============================================================================

/// Creates a test ServerFailure
///
/// Default values:
/// - message: 'Server error'
/// - code: 'SERVER_ERROR'
ServerFailure createServerFailure({
  String message = 'Server error',
  String? code,
}) {
  return ServerFailure(message, code: code ?? 'SERVER_ERROR');
}

/// Creates a test CacheFailure
///
/// Default values:
/// - message: 'Cache error'
/// - code: 'CACHE_ERROR'
CacheFailure createCacheFailure({
  String message = 'Cache error',
  String? code,
}) {
  return CacheFailure(message, code: code ?? 'CACHE_ERROR');
}

/// Creates a test AuthFailure
///
/// Default values:
/// - message: 'Authentication failed'
/// - code: 'AUTH_ERROR'
AuthFailure createAuthFailure({
  String message = 'Authentication failed',
  String? code,
}) {
  return AuthFailure(message, code: code ?? 'AUTH_ERROR');
}

// ============================================================================
// JSON Fixtures
// ============================================================================

/// Creates a test user JSON map
Map<String, dynamic> _userJson({
  String id = 'test-user-id',
  String email = 'test@example.com',
  String? name,
  String? avatarUrl,
}) {
  return {
    'id': id,
    'email': email,
    ...?name != null ? {'name': name} : null,
    ...?avatarUrl != null ? {'avatar_url': avatarUrl} : null,
  };
}

/// Creates a test auth response JSON map
Map<String, dynamic> createAuthResponseJson({
  Map<String, dynamic>? user,
  String token = 'test-access-token',
  String? refreshToken,
}) {
  return {
    'user': user ?? _userJson(),
    'token': token,
    ...?refreshToken != null ? {'refresh_token': refreshToken} : null,
  };
}

// ============================================================================
// Task Fixtures
// ============================================================================

/// Creates a test Task entity
///
/// Default values:
/// - id: 'test-task-id'
/// - title: 'Test Task'
/// - description: null
/// - isCompleted: false
/// - createdAt: current time
/// - updatedAt: current time
Task createTask({
  String? id,
  String title = 'Test Task',
  String? description,
  bool isCompleted = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return Task(
    id: id ?? now.millisecondsSinceEpoch.toString(),
    title: title,
    description: description,
    isCompleted: isCompleted,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

/// Creates a test TaskModel
///
/// Default values match createTask() for consistency.
TaskModel createTaskModel({
  String? id,
  String title = 'Test Task',
  String? description,
  bool isCompleted = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return TaskModel(
    id: id ?? now.millisecondsSinceEpoch.toString(),
    title: title,
    description: description,
    isCompleted: isCompleted,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

/// Creates a list of test tasks
List<Task> createTaskList({int count = 3, bool includeCompleted = false}) {
  return List.generate(
    count,
    (index) => createTask(
      id: 'task-$index',
      title: 'Task $index',
      description: 'Description for task $index',
      isCompleted: includeCompleted && index.isEven,
    ),
  );
}

/// Creates a test task JSON map
Map<String, dynamic> createTaskJson({
  String? id,
  String title = 'Test Task',
  String? description,
  bool isCompleted = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return {
    'id': id ?? now.millisecondsSinceEpoch.toString(),
    'title': title,
    ...?description != null ? {'description': description} : null,
    'is_completed': isCompleted,
    'created_at': (createdAt ?? now).toIso8601String(),
    'updated_at': (updatedAt ?? now).toIso8601String(),
  };
}
