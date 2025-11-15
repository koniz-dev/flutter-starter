import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Implementation of authentication repository
class AuthRepositoryImpl implements AuthRepository {
  /// Creates an [AuthRepositoryImpl] with the given [remoteDataSource] and
  /// [localDataSource]
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Remote data source for API calls
  final AuthRemoteDataSource remoteDataSource;

  /// Local data source for caching
  final AuthLocalDataSource localDataSource;

  @override
  Future<Result<User>> login(String email, String password) async {
    try {
      final authResponse = await remoteDataSource.login(email, password);
      await localDataSource.cacheUser(authResponse.user);
      await localDataSource.cacheToken(authResponse.token);
      if (authResponse.refreshToken != null) {
        await localDataSource.cacheRefreshToken(authResponse.refreshToken!);
      }
      return Success(authResponse.user.toEntity());
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
    } on Exception catch (e) {
      return ResultFailure('Unexpected error: $e');
    }
  }

  @override
  Future<Result<User>> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      final authResponse = await remoteDataSource.register(
        email,
        password,
        name,
      );
      await localDataSource.cacheUser(authResponse.user);
      await localDataSource.cacheToken(authResponse.token);
      if (authResponse.refreshToken != null) {
        await localDataSource.cacheRefreshToken(authResponse.refreshToken!);
      }
      return Success(authResponse.user.toEntity());
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
    } on Exception catch (e) {
      return ResultFailure('Unexpected error: $e');
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
    } on Exception catch (e) {
      return ResultFailure('Unexpected error: $e');
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
    } on Exception catch (e) {
      return ResultFailure('Unexpected error: $e');
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
    } on Exception catch (e) {
      return ResultFailure('Unexpected error: $e');
    }
  }

  @override
  Future<Result<String>> refreshToken() async {
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null) {
        return const ResultFailure('No refresh token available');
      }

      final authResponse = await remoteDataSource.refreshToken(refreshToken);
      await localDataSource.cacheToken(authResponse.token);
      if (authResponse.refreshToken != null) {
        await localDataSource.cacheRefreshToken(
          authResponse.refreshToken!,
        );
      }
      return Success(authResponse.token);
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
    } on Exception catch (e) {
      return ResultFailure('Unexpected error: $e');
    }
  }
}
