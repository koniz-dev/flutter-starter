import 'package:flutter_starter/features/auth/domain/entities/user.dart';

// "After (Exceptions)" from the doc: the repository contract and use case.
abstract class AuthRepository {
  Future<User> login(String email, String password);
}

class LoginUseCase {
  LoginUseCase(this.repository);
  final AuthRepository repository;

  Future<User> call(String email, String password) async {
    return await repository.login(email, password);
  }
}
