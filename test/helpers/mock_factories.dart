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
