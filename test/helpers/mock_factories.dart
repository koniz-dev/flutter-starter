import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/is_authenticated_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/tasks/data/datasources/tasks_local_datasource.dart';
import 'package:flutter_starter/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/create_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/delete_task_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_task_by_id_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/toggle_task_completion_usecase.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/update_task_usecase.dart';
import 'package:mocktail/mocktail.dart';

/// Mock classes for testing
///
/// These mock classes extend Mock from mocktail and implement the interfaces
/// they're mocking. Use these in tests instead of creating mocks manually.

// ============================================================================
// Core Mocks
// ============================================================================

class MockApiClient extends Mock implements ApiClient {}

class MockStorageService extends Mock implements StorageService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

// ============================================================================
// Auth Feature Mocks
// ============================================================================

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockIsAuthenticatedUseCase extends Mock
    implements IsAuthenticatedUseCase {}

// ============================================================================
// Tasks Feature Mocks
// ============================================================================

class MockTasksRepository extends Mock implements TasksRepository {}

class MockTasksLocalDataSource extends Mock implements TasksLocalDataSource {}

class MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

class MockGetTaskByIdUseCase extends Mock implements GetTaskByIdUseCase {}

class MockCreateTaskUseCase extends Mock implements CreateTaskUseCase {}

class MockUpdateTaskUseCase extends Mock implements UpdateTaskUseCase {}

class MockDeleteTaskUseCase extends Mock implements DeleteTaskUseCase {}

class MockToggleTaskCompletionUseCase extends Mock
    implements ToggleTaskCompletionUseCase {}

// ============================================================================
// Mock Factories
// ============================================================================

/// Creates a configured mock AuthRepository
///
/// Returns a MockAuthRepository instance that can be configured in tests.
MockAuthRepository createMockAuthRepository() {
  return MockAuthRepository();
}

/// Creates a configured mock AuthRemoteDataSource
///
/// Returns a MockAuthRemoteDataSource instance that can be configured in tests.
MockAuthRemoteDataSource createMockAuthRemoteDataSource() {
  return MockAuthRemoteDataSource();
}

/// Creates a configured mock AuthLocalDataSource
///
/// Returns a MockAuthLocalDataSource instance that can be configured in tests.
MockAuthLocalDataSource createMockAuthLocalDataSource() {
  return MockAuthLocalDataSource();
}

/// Creates a configured mock ApiClient
///
/// Returns a MockApiClient instance that can be configured in tests.
MockApiClient createMockApiClient() {
  return MockApiClient();
}

/// Creates a configured mock StorageService
///
/// Returns a MockStorageService instance that can be configured in tests.
MockStorageService createMockStorageService() {
  return MockStorageService();
}

/// Creates a configured mock SecureStorageService
///
/// Returns a MockSecureStorageService instance that can be configured in tests.
MockSecureStorageService createMockSecureStorageService() {
  return MockSecureStorageService();
}

/// Creates a configured mock LoginUseCase
///
/// Returns a MockLoginUseCase instance that can be configured in tests.
MockLoginUseCase createMockLoginUseCase() {
  return MockLoginUseCase();
}

/// Creates a configured mock RegisterUseCase
///
/// Returns a MockRegisterUseCase instance that can be configured in tests.
MockRegisterUseCase createMockRegisterUseCase() {
  return MockRegisterUseCase();
}

/// Creates a configured mock LogoutUseCase
///
/// Returns a MockLogoutUseCase instance that can be configured in tests.
MockLogoutUseCase createMockLogoutUseCase() {
  return MockLogoutUseCase();
}

/// Creates a configured mock RefreshTokenUseCase
///
/// Returns a MockRefreshTokenUseCase instance that can be configured in tests.
MockRefreshTokenUseCase createMockRefreshTokenUseCase() {
  return MockRefreshTokenUseCase();
}

/// Creates a configured mock GetCurrentUserUseCase
///
/// Returns a MockGetCurrentUserUseCase instance that can be configured in
/// tests.
MockGetCurrentUserUseCase createMockGetCurrentUserUseCase() {
  return MockGetCurrentUserUseCase();
}

/// Creates a configured mock IsAuthenticatedUseCase
///
/// Returns a MockIsAuthenticatedUseCase instance that can be configured in
/// tests.
MockIsAuthenticatedUseCase createMockIsAuthenticatedUseCase() {
  return MockIsAuthenticatedUseCase();
}

/// Creates a configured mock TasksRepository
///
/// Returns a MockTasksRepository instance that can be configured in tests.
MockTasksRepository createMockTasksRepository() {
  return MockTasksRepository();
}

/// Creates a configured mock TasksLocalDataSource
///
/// Returns a MockTasksLocalDataSource instance that can be configured in tests.
MockTasksLocalDataSource createMockTasksLocalDataSource() {
  return MockTasksLocalDataSource();
}

/// Creates a configured mock GetAllTasksUseCase
///
/// Returns a MockGetAllTasksUseCase instance that can be configured in tests.
MockGetAllTasksUseCase createMockGetAllTasksUseCase() {
  return MockGetAllTasksUseCase();
}

/// Creates a configured mock GetTaskByIdUseCase
///
/// Returns a MockGetTaskByIdUseCase instance that can be configured in tests.
MockGetTaskByIdUseCase createMockGetTaskByIdUseCase() {
  return MockGetTaskByIdUseCase();
}

/// Creates a configured mock CreateTaskUseCase
///
/// Returns a MockCreateTaskUseCase instance that can be configured in tests.
MockCreateTaskUseCase createMockCreateTaskUseCase() {
  return MockCreateTaskUseCase();
}

/// Creates a configured mock UpdateTaskUseCase
///
/// Returns a MockUpdateTaskUseCase instance that can be configured in tests.
MockUpdateTaskUseCase createMockUpdateTaskUseCase() {
  return MockUpdateTaskUseCase();
}

/// Creates a configured mock DeleteTaskUseCase
///
/// Returns a MockDeleteTaskUseCase instance that can be configured in tests.
MockDeleteTaskUseCase createMockDeleteTaskUseCase() {
  return MockDeleteTaskUseCase();
}

/// Creates a configured mock ToggleTaskCompletionUseCase
///
/// Returns a MockToggleTaskCompletionUseCase instance that can be configured
/// in tests.
MockToggleTaskCompletionUseCase createMockToggleTaskCompletionUseCase() {
  return MockToggleTaskCompletionUseCase();
}
