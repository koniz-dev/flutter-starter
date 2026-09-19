import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
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
    this.httpCache,
  });

  /// Remote data source for API calls
  final AuthRemoteDataSource remoteDataSource;

  /// Local data source for caching
  final AuthLocalDataSource localDataSource;

  /// Locally persisted HTTP response cache, cleared on logout.
  ///
  /// Optional so existing call sites keep compiling; production wiring
  /// supplies it from `apiClientProvider`.
  final IHttpResponseCache? httpCache;

  @override
  Future<Result<User>> login(String email, String password) async {
    try {
      final authResponse = await remoteDataSource.login(email, password);
      await localDataSource.cacheUser(authResponse.user);
      await localDataSource.cacheToken(authResponse.token);
      if (authResponse.refreshToken != null) {
        await localDataSource.cacheRefreshToken(authResponse.refreshToken!);
      }
      return Success(authResponse.user);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
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
      return Success(authResponse.user);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  /// Logs the current user out.
  ///
  /// Local teardown is **unconditional**: the remote call is best-effort and
  /// the teardown - [AuthLocalDataSource.clearCache], which drops the cached
  /// user blob *and* every token, refresh token included, plus the HTTP
  /// response cache (#77) - runs even when it throws. Sequencing
  /// the teardown after the network call inside one `try` is what used to leave
  /// a live refresh token on the device whenever the server was unreachable, a
  /// 500, or had no `/auth/logout` route at all.
  ///
  /// The returned [Result] still reports a remote failure, so a caller can
  /// never mistake an unreachable server for a clean server-side sign-out. If
  /// the local teardown *also* fails, that failure is the one returned: a
  /// session still sitting on the device is the more serious of the two, and it
  /// is the one the caller must not paper over.
  @override
  Future<Result<void>> logout() async {
    // `on Object`: the remote call can throw an Error as well as an Exception
    // (a missing platform plugin, a decode failure), and neither may skip the
    // teardown below.
    Object? remoteError;
    try {
      await remoteDataSource.logout();
    } on Object catch (e) {
      remoteError = e;
    }

    try {
      await localDataSource.clearCache();
      // Cached HTTP bodies are local session state too - drop them with the
      // rest of it, or the next sign-in can be served the previous user's
      // responses (#77).
      await httpCache?.clearCache();
    } on Object catch (e) {
      return ResultFailure(_asFailure(e));
    }

    if (remoteError != null) {
      return ResultFailure(_asFailure(remoteError));
    }
    return const Success(null);
  }

  /// Maps anything thrown to a [Failure].
  ///
  /// [ExceptionToFailureMapper] only accepts an [Exception]; logout has to
  /// survive an [Error] too, so those are reported as [UnknownFailure] rather
  /// than escaping a method whose whole job is to not leave a session behind.
  static Failure _asFailure(Object error) => error is Exception
      ? ExceptionToFailureMapper.map(error)
      : UnknownFailure('Unexpected error: $error', code: 'UNKNOWN_ERROR');

  @override
  Future<Result<User?>> getCurrentUser() async {
    try {
      final cachedUser = await localDataSource.getCachedUser();
      return Success(cachedUser);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  /// Whether a usable session is present on this device.
  ///
  /// Requires a token **and** a cached user. Reading the user alone reported
  /// `true` after `AuthInterceptor` force-logged-out on a failed refresh, which
  /// clears tokens: every subsequent request then 401'd and re-triggered a
  /// refresh that could not succeed.
  @override
  Future<Result<bool>> isAuthenticated() async {
    try {
      final token = await localDataSource.getToken();
      if (token == null || token.isEmpty) {
        return const Success(false);
      }
      final cachedUser = await localDataSource.getCachedUser();
      return Success(cachedUser != null);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  @override
  Future<Result<String>> refreshToken() async {
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null) {
        return const ResultFailure(
          UnknownFailure('No refresh token available'),
        );
      }

      final authResponse = await remoteDataSource.refreshToken(refreshToken);
      await localDataSource.cacheToken(authResponse.token);
      if (authResponse.refreshToken != null) {
        await localDataSource.cacheRefreshToken(authResponse.refreshToken!);
      }
      return Success(authResponse.token);
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
}
