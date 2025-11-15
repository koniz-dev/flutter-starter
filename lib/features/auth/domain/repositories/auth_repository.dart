import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';

/// Authentication repository interface (domain layer)
abstract class AuthRepository {
  /// Login with email and password
  Future<Result<User>> login(String email, String password);

  /// Register new user
  Future<Result<User>> register(String email, String password, String name);

  /// Logout current user
  Future<Result<void>> logout();

  /// Get current user
  Future<Result<User?>> getCurrentUser();

  /// Check if user is authenticated
  Future<Result<bool>> isAuthenticated();

  /// Refresh authentication token
  Future<Result<String>> refreshToken();
}
