import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Use case for getting the current authenticated user
class GetCurrentUserUseCase {
  /// Creates a [GetCurrentUserUseCase] with the given [repository]
  GetCurrentUserUseCase(this.repository);

  /// Authentication repository for getting current user
  final AuthRepository repository;

  /// Executes getting the current authenticated user
  Future<Result<User?>> call() async {
    return repository.getCurrentUser();
  }
}
