import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Use case for user logout
class LogoutUseCase {
  /// Creates a [LogoutUseCase] with the given [repository]
  LogoutUseCase(this.repository);

  /// Authentication repository for logout operations
  final AuthRepository repository;

  /// Executes logout for the current user
  Future<Result<void>> call() async {
    return repository.logout();
  }
}
