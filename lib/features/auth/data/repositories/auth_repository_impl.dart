import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
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
  /// ask the user for - checks it before writing.
  ///
  /// Optional in the constructor so existing call sites keep compiling; a
  /// repository given its own counter still guards its own writes, it just
  /// cannot see terminations raised by the interceptor.
  final SessionGeneration sessionGeneration;

  /// What a login or register body the app cannot parse fails with.
  ///
  /// The generated `fromJson` casts with `as String`, so an int user id or a
  /// missing `token` throws a `TypeError` - an [Error], which the
  /// `on Exception` clauses never caught. It escaped the `Result` contract
  /// and left the login screen loading forever.
  /// Nothing has been cached at that point:
  /// parsing happens before the first write.
  static const _unreadableResponse = ServerFailure(
    'The server sent a response this app could not read.',
    code: 'INVALID_AUTH_RESPONSE',
  );

  /// What a refresh body the app cannot parse fails with.
  ///
  /// Same cause as [_unreadableResponse] - a `TypeError` out of the generated
  /// `fromJson` - which escaped `refreshToken()` and made
  /// `AuthNotifier.refreshToken()` throw. An [UnknownFailure], not a
  /// [ServerFailure], on purpose: `AuthInterceptor` keeps the session only for
  /// failures known to be transport trouble, and a body that cannot be read
  /// will not read better on the next attempt, so the session ends - fail
  /// closed - rather than every 401 refreshing into the same wall.
  static const _unreadableRefreshResponse = UnknownFailure(
    'The server sent a token refresh response this app could not read.',
    code: 'INVALID_AUTH_RESPONSE',
  );

  /// Maps a failed sign-in or registration.
  ///
  /// An [AuthFailure] here is the server rejecting the credentials the user
  /// just typed - a 401 from the login endpoint - not a session that ended.
  /// It is tagged [FailureCodes.invalidCredentials] so the screen says so
  /// instead of rendering `failureAuth`, "your session has ended".
  static Failure _signInFailure(Exception exception) {
    final failure = ExceptionToFailureMapper.map(exception);
    if (failure is! AuthFailure) return failure;
    return AuthFailure(
      failure.message,
      code: FailureCodes.invalidCredentials,
    );
  }

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
    } on Exception catch (e) {
      return ResultFailure(_signInFailure(e));
    } on Object catch (_) {
      return const ResultFailure(_unreadableResponse);
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
    } on Exception catch (e) {
      return ResultFailure(_signInFailure(e));
    } on Object catch (_) {
      return const ResultFailure(_unreadableResponse);
    }
  }

  /// Logs the current user out.
  ///
  /// Local teardown is **unconditional**: the remote call is best-effort and
  /// the teardown - [AuthLocalDataSource.clearCache], which drops the cached
  /// user blob *and* every token, refresh token included, plus the HTTP
  /// response cache - runs even when it throws. Sequencing
  /// the teardown after the network call inside one `try` is what used to leave
  /// a live refresh token on the device whenever the server was unreachable, a
  /// 500, or had no `/auth/logout` route at all.
  ///
  /// The teardown's own steps are independent of each other for the same
  /// reason: each is guarded separately and a failure - or absence - of one
  /// must not skip the rest. Making them unconditional relative to the
  /// *remote* call but still coupled to *each other* left the same outcome
  /// reachable one layer down.
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
    // and re-persist the pair being removed.
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

    // Every teardown step below is guarded on its own, and no step is
    // reachable only through another - the same discipline
    // `AuthInterceptor._logoutUser()` has always applied to the forced path.
    // Chaining these two as sequential awaits inside one `try` meant a
    // throwing `clearCache()` skipped the HTTP cache entirely, leaving every
    // `http_cache_*` body in plaintext shared_preferences on a device whose
    // user had just asked to be signed out.
    //
    // The first failure is the one reported: it is the step whose state the
    // caller most needs to know survived, and reporting later ones would hide
    // it. Nothing here returns early - a `return` inside a teardown sequence
    // has already caused skipped teardown steps twice.
    Object? localError;

    try {
      await localDataSource.clearCache();
    } on Object catch (e) {
      localError = e;
    }

    // Cached HTTP bodies are local session state too - drop them with the
    // rest of it, or the next sign-in can be served the previous user's
    // responses.
    final cache = httpCache;
    if (cache != null) {
      try {
        await cache.clearCache();
      } on Object catch (e) {
        localError ??= e;
      }
    }

    // A session still sitting on the device outranks an unreachable server,
    // so a local failure is reported in preference to a remote one.
    if (localError != null) {
      return ResultFailure(_asFailure(localError));
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
  /// tokenless device straight into the authenticated shell: the user
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
  /// a token here but not there is exactly the split that once let the two
  /// disagree.
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
  /// signed-out device with a live access *and* refresh token.
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
        // No credential to revive the session with, which is the same thing to
        // a caller as a rejected one: only a fresh sign-in gets back in.
        return const ResultFailure(
          UnknownFailure(
            'No refresh token available',
            code: AuthErrorCodes.refreshTokenExpired,
          ),
        );
      }

      final authResponse = await remoteDataSource.refreshToken(refreshToken);
      const stale = ResultFailure<String>(
        UnknownFailure(
          'Session ended while the token refresh was in flight',
          code: AuthErrorCodes.sessionTerminated,
        ),
      );
      // Each check sits directly before the write it guards, with no await
      // between them, so a logout that starts after the check issues its clear
      // after that write. Where the platform store handles calls in order
      // (flutter_secure_storage on Android and iOS), the clear also lands after
      // it; elsewhere this narrows the window rather than closing it. A single
      // check before both writes let a logout landing during the first write
      // clear the store, and the refresh token was then written after it.
      if (!sessionGeneration.isCurrent(generation)) return stale;
      await localDataSource.cacheToken(authResponse.token);
      if (authResponse.refreshToken != null) {
        if (!sessionGeneration.isCurrent(generation)) return stale;
        await localDataSource.cacheRefreshToken(authResponse.refreshToken!);
      }
      if (!sessionGeneration.isCurrent(generation)) return stale;
      return Success(authResponse.token);
    } on AppException catch (e) {
      return ResultFailure(_mapRefreshFailure(e));
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (_) {
      return const ResultFailure(_unreadableRefreshResponse);
    }
  }

  /// HTTP statuses from the refresh endpoint that mean the refresh token is
  /// dead. See [_mapRefreshFailure].
  static const Set<int> _deadRefreshTokenStatuses = {400, 401, 403};

  /// Maps a failed refresh round trip, tagging the cases that mean the refresh
  /// token itself is dead with [AuthErrorCodes.refreshTokenExpired].
  ///
  /// Two exception shapes mean that. The first is an [AuthException], which a
  /// custom data source raises for exactly this reason. The second is a
  /// [ServerException] whose status is in [_deadRefreshTokenStatuses]: the
  /// server rejecting the very token it was handed.
  ///
  /// - **401** is what many REST backends send for a dead refresh token.
  /// - **400** is what an OAuth 2.0 server sends: RFC 6749 section 5.2 answers
  ///   a revoked or expired refresh token with `400 invalid_grant`.
  /// - **403** is what many servers send for a token they refuse.
  ///
  /// Tagging only 401 left the other two indistinguishable from a 503, so a
  /// dead refresh token never ended the session.
  ///
  /// Everything else is transport trouble and must leave the session alone:
  /// a timeout, a connection error, any 5xx, and the two 4xx statuses that
  /// mean "try again later" rather than "never" - 408 Request Timeout and
  /// 429 Too Many Requests.
  ///
  /// The tag is set *here*, in the layer that knows what the round trip meant,
  /// because the caller cannot tell. The decision used to be made a layer up by
  /// substring-matching `failure.message`,
  /// which fired on unrelated errors and still missed this one: the default
  /// message for a 401 is "Unauthorized. Please login again." and contains no
  /// "refresh" at all.
  Failure _mapRefreshFailure(AppException exception) {
    final rejected =
        exception is AuthException ||
        (exception is ServerException &&
            _deadRefreshTokenStatuses.contains(exception.statusCode));
    if (!rejected) {
      return ExceptionToFailureMapper.map(exception);
    }
    // Built rather than copied: `Failure.copyWith` falls back to the existing
    // code (`code ?? this.code`) and so cannot replace one the server sent.
    return AuthFailure(
      exception.message,
      code: AuthErrorCodes.refreshTokenExpired,
    );
  }
}
