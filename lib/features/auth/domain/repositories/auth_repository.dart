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

  /// The user of the session this device can use, or null when there is none.
  ///
  /// "None" includes a device that still holds a cached user but no usable
  /// credentials: an implementation must consult the token store, not just the
  /// cached user. This is the boot path's only source of truth (#85).
  Future<Result<User?>> getCurrentUser();

  /// Whether a usable session is present, i.e. `getCurrentUser() != null`.
  ///
  /// Implementations must keep the two in agreement; a guard that disagrees
  /// with the boot path is the defect this contract exists to prevent.
  Future<Result<bool>> isAuthenticated();

  /// Refresh authentication token
  Future<Result<String>> refreshToken();
}
