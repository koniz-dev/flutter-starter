import 'dart:async';

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
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
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
    this.pendingLogoutLimit = const Duration(seconds: 30),
  }) : sessionGeneration = sessionGeneration ?? SessionGeneration();

  /// How long a sign-in waits for a pending logout to finish tearing down
  /// before it fails with [AuthErrorCodes.signOutInProgress].
  final Duration pendingLogoutLimit;

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
  /// The generated `fromJson` throws a `TypeError` (an [Error], not an
  /// [Exception]) for an int user id or a missing `token`; it is caught and
  /// reported as this. Nothing has been cached at that point: parsing
  /// happens before the first write.
  static const _unreadableResponse = ServerFailure(
    'The server sent a response this app could not read.',
    code: 'INVALID_AUTH_RESPONSE',
  );

  /// What a refresh body the app cannot parse fails with.
  ///
  /// Same cause as [_unreadableResponse]. An [UnknownFailure], not a
  /// [ServerFailure], on purpose: `AuthInterceptor` keeps the session only for
  /// transport trouble, and a body that cannot be read will not read better
  /// next time, so the session ends (fail closed).
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
  Future<Result<User>> login(String email, String password) =>
      _signIn(() => remoteDataSource.login(email, password));

  @override
  Future<Result<User>> register(String email, String password, String name) =>
      _signIn(() => remoteDataSource.register(email, password, name));

  /// Signs in through [request] ([login] and [register]).
  Future<Result<User>> _signIn(
    Future<AuthResponseModel> Function() request,
  ) async {
    // Synchronously, before any await: a different credential set is about
    // to land, so a refresh already in flight belongs to the session being
    // replaced, and a logout called right after this one ends this sign-in.
    sessionGeneration.invalidate();
    final generation = sessionGeneration.current;
    // A logout still tearing down would delete what this sign-in stores.
    if (!await _afterPendingLogouts()) {
      return const ResultFailure(_signOutInProgress);
    }
    if (!sessionGeneration.isCurrent(generation)) {
      return const ResultFailure(_signInSessionEnded);
    }
    try {
      final authResponse = await request();
      return await _persistSignIn(authResponse, generation);
    } on Exception catch (e) {
      return ResultFailure(_signInFailure(e));
    } on Object catch (_) {
      return const ResultFailure(_unreadableResponse);
    }
  }

  static const _signInSessionEnded = UnknownFailure(
    'Session ended while the sign-in was in flight',
    code: AuthErrorCodes.sessionTerminated,
  );

  static const _signOutInProgress = UnknownFailure(
    'Still signing out of the previous session; try again',
    code: AuthErrorCodes.signOutInProgress,
  );

  /// Logs the current user out.
  ///
  /// The local teardown - [AuthLocalDataSource.clearCache] (the cached user
  /// and every token) and the HTTP response cache - is **unconditional**: it
  /// runs whatever the best-effort server call does, and each step runs even
  /// when another fails or is absent, so an unreachable server or one failed
  /// step never leaves a credential on the device.
  ///
  /// The returned [Result] reports a remote failure, so an unreachable server
  /// is not mistaken for a clean server-side sign-out. A local failure wins
  /// over a remote one: a session still on the device is the more serious.
  @override
  Future<Result<void>> logout() {
    // Registered before `_logout` invalidates, so a sign-in started by a
    // session listener already sees it.
    final done = Completer<void>();
    sessionGeneration.trackTeardown(done.future);
    final run = _logout();
    done.complete(run.then<void>((_) {}));
    return run;
  }

  /// Waits until no logout is tearing down - this repository's or
  /// `AuthInterceptor`'s forced one, both tracked on [sessionGeneration] -
  /// and false if that takes longer than [pendingLogoutLimit].
  ///
  /// A teardown deletes whatever credentials are stored when its steps run,
  /// so a sign-in must not store its own while any teardown is running.
  Future<bool> _afterPendingLogouts() =>
      sessionGeneration.teardownsSettled(pendingLogoutLimit);

  Future<Result<void>> _logout() async {
    // Synchronously, before any await: a refresh already in flight is stale
    // from this instant and must not re-persist the pair being removed.
    sessionGeneration.invalidate();

    // Read before the teardown deletes it, so the server can revoke it. A
    // failed read still signs out. `on Object` here and below: an Error must
    // not skip the teardown either.
    String? refreshToken;
    try {
      refreshToken = await localDataSource.getRefreshToken();
    } on Object {
      refreshToken = null;
    }

    Object? remoteError;
    try {
      await remoteDataSource.logout(refreshToken: refreshToken);
    } on Object catch (e) {
      remoteError = e;
    }

    // Each step is guarded on its own and none returns early, so a failing
    // step never skips the next (as in `AuthInterceptor._logoutUser()`). The
    // first failure is the one reported.
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
  /// Requires a non-empty access token **as well as** the cached user blob:
  /// they live in different stores, and a forced logout can clear the token
  /// while the blob survives a failed removal. The blob alone would boot a
  /// tokenless device into the authenticated shell.
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
  /// Defined as `getCurrentUser() != null`, so the boot path (which reads the
  /// user) and every guard (which reads this predicate) cannot disagree.
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

  /// Stores a sign-in's user and credentials, checking before each write
  /// that the session [generation] is still current.
  ///
  /// A logout, a forced logout or another sign-in during the round trip ends
  /// this attempt's session, and its writes must not land after that. A stale
  /// attempt fails with
  /// [AuthErrorCodes.sessionTerminated], writes nothing further and clears
  /// nothing - the session that replaced it owns what is in the store. A
  /// write already in flight when the session ended may still land: the
  /// token store makes a later clear win over it (by order, or by a repair if
  /// the write outlived the store's wait bound), but the cached user blob has
  /// no such queue.
  Future<Result<User>> _persistSignIn(
    AuthResponseModel authResponse,
    int generation,
  ) async {
    // The discarded tokens are not revoked: the server session they belong
    // to expires on its own.
    const stale = ResultFailure<User>(_signInSessionEnded);
    if (!sessionGeneration.isCurrent(generation)) return stale;
    await localDataSource.cacheUser(authResponse.user);
    if (!sessionGeneration.isCurrent(generation)) return stale;
    await localDataSource.cacheToken(authResponse.token);
    final refreshToken = authResponse.refreshToken;
    if (refreshToken != null) {
      if (!sessionGeneration.isCurrent(generation)) return stale;
      await localDataSource.cacheRefreshToken(refreshToken);
    }
    if (!sessionGeneration.isCurrent(generation)) return stale;
    return Success(authResponse.user);
  }

  /// Exchanges the stored refresh token for a new credential pair.
  ///
  /// Both writes are conditional on the session still being the one this call
  /// started under: [logout], a forced logout or a fresh [login] can replace
  /// the credential set during the round trip, and an unconditional write
  /// would re-arm a signed-out device.
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
      // between: a logout that starts after the check issues its clear after
      // the write, and the token store applies them in that order, so the
      // clear wins.
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
  /// Everything else is transport trouble and must leave the session alone:
  /// a timeout, a connection error, any 5xx, and the two 4xx statuses that
  /// mean "try again later" rather than "never" - 408 Request Timeout and
  /// 429 Too Many Requests.
  ///
  /// The tag is set here, in the layer that knows what the round trip meant;
  /// a caller must not infer it from `failure.message`.
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
