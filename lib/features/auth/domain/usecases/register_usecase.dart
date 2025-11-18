import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Use case for user registration
class RegisterUseCase {
  /// Creates a [RegisterUseCase] with the given [repository]
  RegisterUseCase(this.repository);

  /// Authentication repository for registration operations
  final AuthRepository repository;

  /// Executes registration with [email], [password], and [name]
  Future<Result<User>> call(
    String email,
    String password,
    String name,
  ) async {
    return repository.register(email, password, name);
  }
}
