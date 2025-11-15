import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Use case for checking if user is authenticated
class IsAuthenticatedUseCase {
  /// Creates an [IsAuthenticatedUseCase] with the given [repository]
  IsAuthenticatedUseCase(this.repository);

  /// Authentication repository for checking authentication status
  final AuthRepository repository;

  /// Executes checking if the user is authenticated
  Future<Result<bool>> call() async {
    return repository.isAuthenticated();
  }
}
