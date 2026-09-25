import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
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
    SessionGeneration? sessionGeneration,
  }) : sessionGeneration = sessionGeneration ?? SessionGeneration();

  /// Remote data source for API calls
  final AuthRemoteDataSource remoteDataSource;

  /// Local data source for caching
  final AuthLocalDataSource localDataSource;

  /// Locally persisted HTTP response cache, cleared on logout.
  ///
  /// Optional so existing call sites keep compiling; production wiring
  /// supplies it from `apiClientProvider`.
  final IHttpResponseCache? httpCache;

  /// Which sign-in the credentials on this device belong to.
  ///
  /// Shared with `AuthInterceptor` via `sessionGenerationProvider`. Every
  /// method here that replaces or removes the credential set advances it, and
  /// [refreshToken] - the only method that persists a token it did not itself
  /// ask the user for - checks it before writing
  /// (koniz-dev/flutter-starter#169).
  ///
  /// Optional in the constructor so existing call sites keep compiling; a
  /// repository given its own counter still guards its own writes, it just
  /// cannot see terminations raised by the interceptor.
  final SessionGeneration sessionGeneration;

  @override
  Future<Result<User>> login(String email, String password) async {
    // A different credential set is about to land. Any refresh already in
    // flight belongs to the session being replaced and must not overwrite it.
    sessionGeneration.invalidate();
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
    // Same reason as [login]: this writes a new credential set.
    sessionGeneration.invalidate();
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
    // First, and synchronously, ahead of every await below: the user has asked
    // to be signed out, so a refresh already in flight is stale from this
    // instant. Doing it after the teardown would leave the whole remote call
    // plus `clearCache()` as a window in which that refresh could still land
    // and re-persist the pair being removed (koniz-dev/flutter-starter#169).
    sessionGeneration.invalidate();

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

  /// The user of the session this device can actually use, or null.
  ///
  /// Requires a non-empty access token **as well as** the cached user blob.
  /// The two are written together by [login]/[register] and dropped together
  /// by [logout], but they live in different stores - the user in
  /// [IKeyValueStore], the token in [ITokenStore] - and `AuthInterceptor`'s
  /// forced logout can clear the token while the blob survives a failed
  /// removal. Returning the blob alone is what let a cold start promote a
  /// tokenless device straight into the authenticated shell (#85): the user
  /// saw home, then every request 401'd.
  ///
  /// The token is read first and deliberately not inspected beyond
  /// "present and non-empty" - see [isAuthenticated].
  @override
  Future<Result<User?>> getCurrentUser() async {
    try {
      final token = await localDataSource.getToken();
      if (token == null || token.isEmpty) {
        return const Success(null);
      }
      return Success(await localDataSource.getCachedUser());
    } on AppException catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  /// Whether a usable session is present on this device.
  ///
  /// Defined as `getCurrentUser() != null` and implemented by delegating to it,
  /// so the boot path (which reads the user) and every guard (which reads this
  /// predicate) cannot disagree about whether a device is signed in. Requiring
  /// a token here but not there is exactly the split that produced #85.
  ///
  /// "Present and non-empty" is the whole test. Whether the token is *expired*
  /// is not decidable here: [ITokenStore] holds opaque strings with no expiry
  /// metadata, and only the server can answer it. An expired token therefore
  /// reports a session, and the 401 refresh flow resolves it - see
  /// `AuthNotifier.restoreSession` for the reasoning behind that choice.
  @override
  Future<Result<bool>> isAuthenticated() async {
    final result = await getCurrentUser();
    return switch (result) {
      Success<User?>(:final data) => Success(data != null),
      ResultFailure<User?>(:final failure) => ResultFailure<bool>(failure),
    };
  }

  /// Exchanges the stored refresh token for a new credential pair.
  ///
  /// Both writes below are conditional on the session still being the one this
  /// call started under. A refresh is a read-modify-write across a full
  /// network round trip, and [logout] - or a forced logout in
  /// `AuthInterceptor`, or a fresh [login] - can replace the credential set
  /// while that round trip is open. Writing unconditionally is what re-armed a
  /// signed-out device with a live access *and* refresh token
  /// (koniz-dev/flutter-starter#169).
  ///
  /// A stale refresh reports failure rather than [Success]: it did not produce
  /// a token this session can use. It deliberately does not *clear* anything -
  /// the session that replaced this one may own what is in the store now.
  @override
  Future<Result<String>> refreshToken() async {
    // Read before the round trip; checked immediately before each write.
    final generation = sessionGeneration.current;
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      if (refreshToken == null) {
        return const ResultFailure(
          UnknownFailure('No refresh token available'),
        );
      }

      final authResponse = await remoteDataSource.refreshToken(refreshToken);
      if (!sessionGeneration.isCurrent(generation)) {
        return const ResultFailure(
          UnknownFailure(
            'Session ended while the token refresh was in flight',
            code: 'SESSION_TERMINATED',
          ),
        );
      }
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
