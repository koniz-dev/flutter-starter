import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Use case for refreshing authentication token
class RefreshTokenUseCase {
  /// Creates a [RefreshTokenUseCase] with the given [repository]
  RefreshTokenUseCase(this.repository);

  /// Authentication repository for token refresh operations
  final AuthRepository repository;

  /// Executes token refresh for the current user
  Future<Result<String>> call() async {
    return repository.refreshToken();
  }
}
