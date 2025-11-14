import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/errors/exceptions.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';

/// Implementation of authentication repository
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Result<User>> login(String email, String password) async {
    try {
      final userModel = await remoteDataSource.login(email, password);
      await localDataSource.cacheUser(userModel);
      return Success(userModel.toEntity());
    } on ServerException catch (e) {
      return ResultFailure(
        e.message,
        code: e.code,
      );
    } on NetworkException catch (e) {
      return ResultFailure(
        e.message,
        code: e.code,
      );
    } catch (e) {
      return ResultFailure('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<Result<User>> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      final userModel = await remoteDataSource.register(email, password, name);
      await localDataSource.cacheUser(userModel);
      return Success(userModel.toEntity());
    } on ServerException catch (e) {
      return ResultFailure(
        e.message,
        code: e.code,
      );
    } on NetworkException catch (e) {
      return ResultFailure(
        e.message,
        code: e.code,
      );
    } catch (e) {
      return ResultFailure('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await remoteDataSource.logout();
      await localDataSource.clearCache();
      return const Success(null);
    } on ServerException catch (e) {
      return ResultFailure(
        e.message,
        code: e.code,
      );
    } catch (e) {
      return ResultFailure('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<Result<User?>> getCurrentUser() async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      return Success(cachedUser?.toEntity());
    } on CacheException catch (e) {
      return ResultFailure(
        e.message,
        code: e.code,
      );
    } catch (e) {
      return ResultFailure('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<Result<bool>> isAuthenticated() async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      return Success(cachedUser != null);
    } on CacheException catch (e) {
      return ResultFailure(
        e.message,
        code: e.code,
      );
    } catch (e) {
      return ResultFailure('Unexpected error: ${e.toString()}');
    }
  }
}

