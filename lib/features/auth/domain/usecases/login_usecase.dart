import '../repositories/auth_repository.dart';
import '../../../../core/utils/result.dart';
import '../entities/user.dart';

/// Use case for user login
class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Result<User>> call(String email, String password) async {
    return await repository.login(email, password);
  }
}

