import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Use case for user login
class LoginUseCase {
  /// Creates a [LoginUseCase] with the given [repository]
  LoginUseCase(this.repository);

  /// Authentication repository for login operations
  final AuthRepository repository;

  /// Executes login with [email] and [password]
  Future<Result<User>> call(String email, String password) async {
    return repository.login(email, password);
  }
}
