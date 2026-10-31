import 'dart:async';

// Constructor preserves backward-compatible parameter ordering/signature.
// ignore_for_file: always_put_required_named_parameters_first, lines_longer_than_80_chars

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/adapters/shared_transport_adapter.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/network/request_body_replay.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';

/// Pending request data structure for queuing requests during token refresh
class _PendingRequest {
  _PendingRequest(this.error, this.handler);

  final DioException error;
  final ErrorInterceptorHandler handler;
}

/// Interceptor for adding authentication tokens to requests and handling
/// automatic token refresh on 401 Unauthorized responses
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor] with the given dependencies
  AuthInterceptor({
    ITokenStore? tokenStore,
    SecureStorageService? secureStorageService,
    required Future<Result<String>> Function() refreshToken,
    Dio Function()? retryDioFactory,
    IKeyValueStore? keyValueStore,
    ISessionTerminationSink? sessionSink,
    SessionGeneration? sessionGeneration,
    Duration teardownStepTimeout = const Duration(seconds: 10),
  }) : _teardownStepTimeout = teardownStepTimeout,
       _retryDioFactory = retryDioFactory,
       _keyValueStore = keyValueStore,
       _sessionSink = sessionSink,
       _sessionGeneration = sessionGeneration ?? SessionGeneration(),
       _tokenStore =
           tokenStore ??
           (secureStorageService != null
               ? SecureTokenStore(secureStorageService)
               : throw ArgumentError(
                   'Either tokenStore or secureStorageService must be provided.',
                 )),
       _refreshToken = refreshToken;

  /// Token storage for retrieving and storing authentication tokens
  final ITokenStore _tokenStore;

  /// The longest each step of a forced logout's teardown may take before
  /// the next one runs. A sign-in waits for the teardown, so a step that
  /// never completed used to fail every sign-in after it.
  final Duration _teardownStepTimeout;

  /// The token store this interceptor authenticates from.
  ///
  /// Exposed so other interceptors can make credential-dependent decisions
  /// from the same source of truth instead of inspecting request headers,
  /// which are only populated once [onRequest] has run.
  ITokenStore get tokenStore => _tokenStore;

  /// Non-sensitive storage holding the cached user blob, if wired.
  ///
  /// Needed so a forced logout here leaves the same state as
  /// `AuthRepository.logout()`. Optional only so existing call sites that
  /// construct this interceptor by hand keep compiling; the app wires it in
  /// `lib/features/auth/di/auth_providers.dart`.
  final IKeyValueStore? _keyValueStore;

  /// The running app's session state, if wired.
  ///
  /// Clearing storage is not enough on its own: the app that is *already
  /// running* holds the session in memory, and nothing in this layer is
  /// allowed to know what holds it. A forced logout that only emptied storage
  /// left the authenticated shell on screen, backed by credentials that no
  /// longer existed, until the next cold start.
  ///
  /// A constructor dependency rather than an `attach...` call, unlike
  /// [_responseCache]: the sink is resolvable when `authInterceptorProvider`
  /// builds this interceptor, because it defers reading the notifier until
  /// something actually terminates a session.
  ///
  /// Optional for the same reason [_keyValueStore] is: hand-built call sites
  /// (and every test that drives this interceptor standalone) keep compiling,
  /// and a missing sink degrades to not telling the running app - the
  /// behaviour before the sink existed - rather than to a crash.
  final ISessionTerminationSink? _sessionSink;

  /// Which sign-in the credentials this interceptor writes belong to.
  ///
  /// The 401 handler reads it before awaiting the refresh and re-checks it
  /// before persisting anything, so a logout that lands during the round trip
  /// cannot be undone by the response that arrives after it.
  /// [_logoutUser] advances it for the same
  /// reason in the other direction.
  ///
  /// Shared with `AuthRepositoryImpl` through `sessionGenerationProvider` in
  /// production: two of the three credential writes behind one refresh happen
  /// inside `AuthRepositoryImpl.refreshToken()`, and a per-instance counter
  /// would leave those two unguarded.
  ///
  /// Optional for the same reason [_keyValueStore] and [_sessionSink] are:
  /// hand-built call sites keep compiling. A standalone interceptor still
  /// guards its own writes against its own forced logouts; it simply cannot
  /// see terminations raised elsewhere, because nothing else holds its
  /// counter.
  final SessionGeneration _sessionGeneration;

  /// Locally persisted HTTP response cache, if wired.
  ///
  /// Set by `ApiClient` through [attachResponseCache] rather than by the
  /// constructor: the cache is a `CacheInterceptor` the client builds itself,
  /// so it does not exist yet when this interceptor is constructed in
  /// `authInterceptorProvider`.
  ///
  /// Stays null when nobody attaches one, which mirrors how `httpCache` is
  /// optional in `AuthRepositoryImpl`.
  IHttpResponseCache? _responseCache;

  /// Binds the response cache this interceptor must empty on forced logout.
  ///
  /// Called by `ApiClient` once the cache interceptor is built. Safe to call
  /// more than once; the last cache wins.
  ///
  /// A method rather than the setter `use_setters_to_change_properties` asks
  /// for, to pair with [attachTransport]: both are post-construction wiring
  /// performed by `ApiClient`, and reading them the same way is worth more here
  /// than the lint.
  // ignore: use_setters_to_change_properties
  void attachResponseCache(IHttpResponseCache cache) => _responseCache = cache;

  /// Callback to refresh the access token.
  ///
  /// Intentionally a callback (instead of depending on a repository/provider)
  /// to avoid DI cycles during app bootstrap.
  final Future<Result<String>> Function() _refreshToken;

  /// Optional factory for the Dio instance used to replay the original
  /// request after a successful refresh.
  ///
  /// Production leaves this null: the replay client is built once and borrows
  /// the transport of the client this interceptor is attached to (see
  /// [attachTransport]), so the replay cannot re-enter this interceptor but
  /// still goes through the pinned adapter. Tests inject a factory to point
  /// the replay at a fake [HttpClientAdapter].
  final Dio Function()? _retryDioFactory;

  /// The client this interceptor is installed on, if any.
  ///
  /// Only its transport and base options are borrowed - never its interceptor
  /// chain, which would re-enter this interceptor on every replay.
  Dio? _hostDio;

  /// Single replay client, created on first use and reused afterwards.
  Dio? _retryDio;

  /// Binds this interceptor to the client it is installed on.
  ///
  /// Called by `ApiClient` after the transport (including certificate
  /// pinning) is configured, so replayed requests use the same adapter
  /// instead of a fresh, unpinned one.
  void attachTransport(Dio dio) {
    _hostDio = dio;
    // Drop any replay client built against the previous transport.
    _closeRetryDio();
  }

  /// Returns the single replay client, creating it on first use.
  Dio retryDio() {
    final existing = _retryDio;
    if (existing != null) {
      return existing;
    }

    final factory = _retryDioFactory;
    final created = factory != null ? factory() : _buildRetryDio();
    _retryDio = created;
    return created;
  }

  Dio _buildRetryDio() {
    final host = _hostDio;
    final dio = Dio(
      BaseOptions(
        baseUrl:
            host?.options.baseUrl ??
            AppConfig.baseUrl + ApiEndpoints.apiVersion,
        connectTimeout:
            host?.options.connectTimeout ??
            Duration(seconds: AppConfig.apiConnectTimeout),
        receiveTimeout:
            host?.options.receiveTimeout ??
            Duration(seconds: AppConfig.apiReceiveTimeout),
        sendTimeout:
            host?.options.sendTimeout ??
            Duration(seconds: AppConfig.apiSendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (host != null) {
      // Borrow the host transport so pinning applies to the replay too.
      dio.httpClientAdapter = SharedTransportAdapter(
        () => host.httpClientAdapter,
      );
      // And the host's logging and performance tracing, in the host's
      // order. A successful replay is resolved from onError, which in dio
      // ends the host chain: no interceptor there sees the replay's
      // response, so without these the replayed response was never logged
      // and the request's trace recorded the
      // 401 or was never stopped. ApiLoggingInterceptor redacts the
      // replay's fresh Authorization header like any other.
      dio.interceptors.addAll(
        host.interceptors.where(
          (i) => i is ApiLoggingInterceptor || i is PerformanceInterceptor,
        ),
      );
    } else {
      // Not attached to a client (standalone use): pin the replay directly.
      final pinned = SslPinning.fromConfig().createAdapter();
      if (pinned != null) {
        dio.httpClientAdapter = pinned;
      }
    }

    return dio;
  }

  void _closeRetryDio() {
    _retryDio?.close(force: true);
    _retryDio = null;
  }

  /// Releases the replay client and its connection pool.
  ///
  /// Wired to provider disposal; safe to call more than once.
  void dispose() => _closeRetryDio();

  /// Flag to track if token refresh is in progress
  bool _isRefreshing = false;

  /// Queue of pending requests waiting for token refresh to complete
  final List<_PendingRequest> _pendingRequests = [];

  /// `RequestOptions.extra` key recording that the `Authorization` header was
  /// written by [onRequest] rather than attached by the caller.
  static const String _injectedAuthorizationKey = 'auth_interceptor_injected';

  /// The failure code a refresher sets when the refresh token itself is dead.
  ///
  /// The same string as `AuthErrorCodes.refreshTokenExpired`, which core
  /// cannot import; a test pins the two
  /// together. See [_endsSession].
  static const String refreshTokenExpiredCode = 'REFRESH_TOKEN_EXPIRED';

  /// `RequestOptions.extra` key recording the [SessionGeneration] a request
  /// was first sent under. See [onRequest].
  static const String _issuedUnderGenerationKey = 'auth_session_generation';

  /// Endpoints that should not trigger token refresh
  static const List<String> _excludedEndpoints = [
    ApiEndpoints.login,
    ApiEndpoints.register,
    ApiEndpoints.refreshToken,
    ApiEndpoints.logout,
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // An absolute URL on another origin - a presigned upload, a CDN, a
    // pagination link - is not this API: the token is never sent there, and
    // a header the caller attached is theirs to keep.
    if (!_targetsApiOrigin(options)) return super.onRequest(options, handler);

    // A re-send - a `RetryInterceptor` attempt runs the whole chain again with
    // the earlier attempt's `extra` - of a request first sent under a session
    // that has since ended. Authorising it with the token stored now would
    // send it as whoever signed in during the backoff, and hand that user's
    // response to the ended session's caller.
    // The first send stamps the generation, so only a re-send can find it
    // stale here; the check after the token read covers both.
    final issuedUnder = options.extra.putIfAbsent(
      _issuedUnderGenerationKey,
      () => _sessionGeneration.current,
    );
    if (_rejectIfSessionEnded(issuedUnder, options, handler)) return;

    // Get token from secure storage. dio does not await this callback, so a
    // store that throws - `ITokenStore` is a public seam, and an `Error` gets
    // past the default store's own guard - would call neither `next` nor
    // `reject`: the caller's future would never complete, and the exception
    // would surface as an uncaught zone error.
    final String? token;
    try {
      token = await _tokenStore.getAccessToken();
    } on Object catch (error, stackTrace) {
      options.extra[RetryInterceptor.retryExtraKey] = false;
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: 'Could not read the access token.',
        ),
        true,
      );
      return;
    }

    // Checked again because the read above is a platform call: a sign-out and
    // a different user's sign-in landing while it was pending return *their*
    // token, and sending it would run this session's request - first send or
    // re-send - as the new user.
    if (_rejectIfSessionEnded(issuedUnder, options, handler)) return;

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_injectedAuthorizationKey] = true;
    } else if (options.extra.remove(_injectedAuthorizationKey) == true) {
      // A re-send of a request this interceptor already authorised - a
      // `RetryInterceptor` attempt copies the earlier attempt's headers - and
      // the session has ended since. Leaving the header would put the ended
      // session's bearer token on the wire.
      // Only a header this interceptor wrote is removed; one the caller
      // attached itself is theirs to keep.
      options.headers.remove('Authorization');
    }

    super.onRequest(options, handler);
  }

  /// Rejects [options] when the session it was [issuedUnder] has ended.
  ///
  /// Returns true when it rejected, so the caller stops. The rejection is a
  /// `DioExceptionType.cancel` marked with [RetryInterceptor.retryExtraKey]
  /// `= false`, so it is not re-sent either.
  bool _rejectIfSessionEnded(
    Object? issuedUnder,
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (issuedUnder is! int || _sessionGeneration.isCurrent(issuedUnder)) {
      return false;
    }
    options.extra[RetryInterceptor.retryExtraKey] = false;
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'The session this request was sent under has ended.',
      ),
      true,
    );
    return true;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized - refresh token or logout
    if (err.response?.statusCode == 401) {
      // Another origin's 401 says nothing about this API's session, and it
      // was never sent this API's token.
      if (!_targetsApiOrigin(err.requestOptions) ||
          _shouldExcludeEndpoint(err.requestOptions)) {
        return super.onError(err, handler);
      }

      // A 401 for a request sent under a session that has since ended - its
      // user signed out, and maybe someone else signed in - says nothing about
      // the session that is current now. Refreshing would rotate the *current*
      // user's credentials and replay the ended session's request as them, and
      // with nothing stored it would log out whoever is signing in. Neither
      // happens: the request just fails.
      if (!_issuedUnderCurrentSession(err.requestOptions)) {
        _reject(handler, err);
        return;
      }

      return await _handle401Error(err, handler);
    }

    super.onError(err, handler);
  }

  /// Whether [options] was sent under the session that is current now.
  ///
  /// [onRequest] stamps the generation on every API-origin request; one with
  /// no stamp never went through it, and is judged by its 401 alone as before.
  bool _issuedUnderCurrentSession(RequestOptions options) {
    final issuedUnder = options.extra[_issuedUnderGenerationKey];
    return issuedUnder is! int || _sessionGeneration.isCurrent(issuedUnder);
  }

  /// Whether [options] goes to the API's own origin - the scheme, host and
  /// port of its base URL.
  ///
  /// Judged on [RequestOptions.uri], the URL dio will actually fetch, not on
  /// the path alone. dio sends an absolute path as is, and it *joins* a
  /// relative one to the base URL as strings rather than resolving it: with a
  /// base URL that has no path, `@evil.example/x` or `.evil.example/x` lands
  /// on another host although the path has no scheme. A URL that cannot be
  /// parsed counts as foreign, so it never carries the token.
  ///
  /// A client with no base URL - the interceptor installed on a bare `Dio` -
  /// has no origin to compare against, so every request on it counts as the
  /// API's.
  static bool _targetsApiOrigin(RequestOptions options) {
    final api = Uri.parse(options.baseUrl);
    if (!api.hasAuthority) return true;
    final Uri target;
    try {
      target = options.uri;
    } on FormatException {
      return false;
    }
    return target.scheme == api.scheme &&
        target.host == api.host &&
        target.port == api.port;
  }

  /// Whether [options] targets one of the auth endpoints themselves, whose
  /// 401 means the credentials were refused rather than that a token expired.
  ///
  /// An exact match on the endpoint path, not `contains`: a route that merely
  /// contains `/auth/login` - `/users/auth/login-history` - is an ordinary
  /// authenticated route and must refresh like any other.
  /// The query string is ignored, and an
  /// absolute URL is reduced to its path below the base URL's.
  bool _shouldExcludeEndpoint(RequestOptions options) {
    return _excludedEndpoints.contains(_endpointPath(options));
  }

  /// The endpoint [options] targets, relative to the base URL, with a leading
  /// slash and no query string or trailing slash.
  static String _endpointPath(RequestOptions options) {
    final target = Uri.parse(options.path);
    var path = target.path;
    if (target.hasScheme) {
      final basePath = Uri.parse(options.baseUrl).path;
      if (basePath.isNotEmpty && path.startsWith(basePath)) {
        path = path.substring(basePath.length);
      }
    }
    if (!path.startsWith('/')) path = '/$path';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  /// Handles 401 Unauthorized errors by attempting token refresh
  ///
  /// Every exit path completes both this request's handler and every queued
  /// handler: a handler that is neither resolved nor rejected leaves its
  /// caller awaiting a future that never finishes.
  ///
  /// No exit path persists a credential belonging to a session that ended
  /// while the refresh was in flight. See [_sessionGeneration].
  Future<void> _handle401Error(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // No retry-count check: the replay goes through `retryDio()`, which has
    // no `AuthInterceptor`, so a replay answered 401 cannot re-enter this
    // method - it surfaces from `_retryRequest` below and logs out there. The
    // `X-Retry-Count: 1` header that used to guard this could never be seen on
    // a replay, so the branch only ever fired for a caller that set the header
    // itself, logging it out without trying a refresh, and the header went to
    // the server on every replay.

    // If refresh is already in progress, queue this request
    if (_isRefreshing) {
      return _queueRequest(err, handler);
    }

    // Start token refresh
    _isRefreshing = true;
    String? refreshedToken;

    // Read before the round trip, checked after it: anything that ends the
    // session in between makes this value stale for good.
    final generation = _sessionGeneration.current;

    try {
      final result = await _refreshToken();

      if (!_sessionGeneration.isCurrent(generation)) {
        // The session this refresh belonged to ended while it was in flight -
        // a logout, a forced logout, or a fresh sign-in. Persist nothing and
        // replay nothing: the teardown already emptied the store, and a newer
        // sign-in may have filled it again with credentials that are not ours
        // to overwrite.
        //
        // Deliberately *not* a _logoutUser() call. Whoever advanced the
        // generation has already torn the session down, and repeating it would
        // clear a session that started after this refresh did - the exact
        // damage the guard exists to prevent, inflicted from the other side.
        //
        // refreshedToken stays null, so the `finally` drain rejects every
        // queued request rather than replaying it with a dead token.
        _reject(handler, err);
        return;
      }

      final newToken = result.isSuccess ? result.dataOrNull : null;

      if (result
          case ResultFailure(
            :final failure,
          )
          when !_endsSession(failure)) {
        // Transport trouble on the refresh endpoint, not a dead refresh token:
        // the session is still good, so nothing is torn down and nothing is
        // replayed. The caller fails with the refresh failure as the cause
        // rather than with this 401, whose "please login again" would be
        // false. refreshedToken stays null,
        // so the `finally` drain rejects every queued request too.
        _reject(handler, _refreshFailedTransiently(err, failure));
        return;
      }

      if (newToken == null) {
        // Refresh failed (or returned nothing usable), logout user
        await _logoutUser();
        _reject(handler, err);
        return;
      }

      // Update token in secure storage
      await _tokenStore.setAccessToken(newToken);

      // Checked again because the write above is a platform call: a logout or
      // sign-in landing while it was pending makes the replay belong to a
      // session that has ended, and sending it would put the fresh token on
      // the wire after the user signed out.
      // Same exit as the check above, for the same reasons: no replay, no
      // _logoutUser(), and the `finally` drain rejects every queued request.
      if (!_sessionGeneration.isCurrent(generation)) {
        _reject(handler, err);
        return;
      }
      refreshedToken = newToken;

      // Retry original request with new token.
      //
      // Its own `try`, because a failed replay is not a failed refresh. The
      // token is fresh and stored, so a transient replay failure (a 503, a
      // timeout) fails this one request and nothing else: the session stays,
      // and the `finally` drain still replays the queued requests with the
      // fresh token, exactly as a failed *queued* replay does. Sharing the
      // outer catch used to log the user out and reject every queued request
      // over a single 503.
      //
      // A replay answered 401 is the one exception: the server refused a token
      // it just issued, so the session really is unusable.
      try {
        final retryResponse = await _retryRequest(err, newToken);
        handler.resolve(retryResponse);
      } on Object catch (e) {
        if (e is DioException && e.response?.statusCode == 401) {
          refreshedToken = null;
          await _logoutUser();
        }
        _reject(handler, _asDioException(err, e));
      }
    }
    // Catches Error as well as Exception on purpose: a TypeError thrown while
    // parsing a malformed refresh response used to escape, leaving
    // _isRefreshing stuck true and every later 401 queued forever.
    on Object catch (e) {
      refreshedToken = null;
      await _logoutUser();
      _reject(handler, _asDioException(err, e));
    } finally {
      // Reset before draining: a 401 arriving during the drain must be able
      // to start a fresh refresh rather than queue behind a finished one.
      _isRefreshing = false;
      await _drainPendingRequests(refreshedToken, generation);
    }
  }

  /// Fails the request with [error] **without ending the error chain**.
  ///
  /// In dio's error chain, a bare `handler.reject(error)` stops it outright:
  /// every interceptor registered after this one is skipped (`dio_mixin.dart`
  /// only runs the next error callback for a `next` or `rejectCallFollowing`
  /// state). `reject(error, true)` requests the latter since dio 5.10, but
  /// `next` already continues the chain on every dio 5.x and needs no flag
  /// that a later edit could drop, so this keeps using it. `ApiClient`
  /// registers `RetryInterceptor`, `ApiLoggingInterceptor`
  /// and, last, `ErrorInterceptor` after this one, so a rejected 401 reached
  /// the caller with no domain error inside. `DioNetworkClient` and
  /// `ApiClient._send` then turned it into `NetworkException("Instance of
  /// 'NetworkError'")`: a 401 reported as a connectivity failure, with an
  /// unreadable message, and never logged.
  ///
  /// `next` hands the error on instead, so a 401 this interceptor gives up on
  /// is logged and then mapped by `ErrorInterceptor` - which ends the chain
  /// itself - exactly like any other failing status. Every failure exit in
  /// this class goes through here; a bare `handler.reject(...)` would
  /// reintroduce the bug on that one path.
  ///
  /// Forwarded, but **never re-sent**. The error is marked with
  /// [RetryInterceptor.retryExtraKey] `= false` before it moves on, so
  /// `RetryInterceptor` passes it through instead of replaying it. Every exit
  /// that reaches here has already ended the request's session or given up on
  /// it, and a failed replay's options carry the bearer token minted for the
  /// session that was just torn down: re-sending it put that token on the wire
  /// after the forced logout and handed the caller a success.
  /// An early `reject` once made the same guarantee by accident; this states
  /// it on purpose.
  void _reject(ErrorInterceptorHandler handler, DioException error) {
    error.requestOptions.extra[RetryInterceptor.retryExtraKey] = false;
    handler.next(error);
  }

  /// Whether a failed refresh means the session is over.
  ///
  /// Fails closed. Only two shapes are known to be transport trouble rather
  /// than a dead credential, and only those leave the session alone:
  ///
  /// - a [NetworkFailure], meaning a timeout, connection error or bad
  ///   certificate on the refresh call;
  /// - an untagged [ServerFailure]. `AuthRepositoryImpl` tags the statuses
  ///   that mean the refresh token is dead (400, 401 and 403) with
  ///   [refreshTokenExpiredCode], so what is left is 408, 429 and 5xx.
  ///
  /// Everything else ends the session:
  ///
  /// - the [refreshTokenExpiredCode] tag, on any failure type;
  /// - core's own `NO_TOKEN_REFRESHER`;
  /// - an untagged auth, unknown or other failure from a custom refresher.
  ///
  /// The last case matters: an unrecognised failure is not given the benefit
  /// of the doubt, because a session that can never refresh would otherwise
  /// stay up indefinitely.
  static bool _endsSession(Failure failure) {
    if (failure.code == refreshTokenExpiredCode) return true;
    return failure is! NetworkFailure && failure is! ServerFailure;
  }

  /// The error a request fails with when its refresh failed transiently.
  ///
  /// `DioExceptionType.unknown` with the failure's message, so
  /// `ErrorInterceptor` maps it to a `NetworkException` that says the session
  /// could not be refreshed. The original 401 would map to a
  /// `ServerException` telling the user to sign in again, when the session is
  /// still good.
  DioException _refreshFailedTransiently(DioException original, Failure f) {
    return DioException(
      requestOptions: original.requestOptions,
      error: f,
      message:
          'Could not refresh the session (${f.code ?? f.runtimeType}): '
          '${f.message}',
    );
  }

  /// Wraps a non-Dio failure so the caller still gets a [DioException].
  DioException _asDioException(DioException original, Object error) {
    if (error is DioException) {
      return error;
    }
    return DioException(
      requestOptions: original.requestOptions,
      error: error,
      response: original.response,
      type: original.type,
    );
  }

  /// Retries the original request with a new token
  ///
  /// The body goes through [RequestBodyReplay]: a [FormData] is sent as a
  /// clone, because dio finalizes the original on the first send, and a body
  /// that cannot be read twice fails the replay with a [DioException] naming
  /// the reason.
  Future<Response<dynamic>> _retryRequest(
    DioException err,
    String newToken,
  ) async {
    final requestOptions = err.requestOptions;

    if (!RequestBodyReplay.canReplay(requestOptions.data)) {
      final reason = RequestBodyReplay.reason(requestOptions.data);
      throw DioException(
        requestOptions: requestOptions,
        message: reason,
        error: NetworkException(
          reason,
          code: RequestBodyReplay.notReplayableCode,
        ),
      );
    }

    // Create new request options with updated headers
    final newOptions = requestOptions.copyWith(
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $newToken',
      },
    );

    // Replay through the shared retry client so the transport - and its
    // certificate pinning - matches the original request.
    return await retryDio().request(
      newOptions.path,
      data: RequestBodyReplay.bodyFor(newOptions.data),
      queryParameters: newOptions.queryParameters,
      // Cancelling the original request must abort the replay too.
      cancelToken: requestOptions.cancelToken,
      onSendProgress: requestOptions.onSendProgress,
      onReceiveProgress: requestOptions.onReceiveProgress,
      options: Options(
        method: newOptions.method,
        headers: newOptions.headers,
        contentType: newOptions.contentType,
        responseType: newOptions.responseType,
        followRedirects: newOptions.followRedirects,
        maxRedirects: newOptions.maxRedirects,
        validateStatus: newOptions.validateStatus,
        receiveTimeout: newOptions.receiveTimeout,
        sendTimeout: newOptions.sendTimeout,
        transformTimeout: newOptions.transformTimeout,
        // The original's per-request metadata travels with the replay - its
        // performance trace among it, which the replay client's borrowed
        // PerformanceInterceptor finishes with the replay's outcome.
        extra: Map<String, dynamic>.of(newOptions.extra),
      ),
    );
  }

  /// Queues a request to be retried after token refresh completes
  void _queueRequest(DioException err, ErrorInterceptorHandler handler) {
    _pendingRequests.add(_PendingRequest(err, handler));
  }

  /// Completes every queued request.
  ///
  /// With a [newToken] each one is replayed and resolved (or rejected if the
  /// replay fails). Without one the refresh failed, so each queued handler is
  /// rejected with its own original error - never left dangling.
  ///
  /// [generation] is the session the refresh was started under. A queued
  /// request is **rejected, not replayed**, once that generation is no longer
  /// current: replaying would put `Authorization: Bearer ...` on the wire for
  /// a user who has signed out, and the caller of a request issued before the
  /// logout has no use for its body afterwards. Rejection still completes the
  /// handler, so nothing is stranded.
  ///
  /// The check is inside the loop rather than above it because each replay is
  /// awaited: a logout landing part-way through the drain must stop the
  /// remaining replays too, not only the ones not yet started.
  Future<void> _drainPendingRequests(String? newToken, int generation) async {
    if (_pendingRequests.isEmpty) {
      return;
    }

    final requests = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final pending in requests) {
      // The last check covers a request that queued under an older session
      // than the refresh's, which onError already turns away; kept here so the
      // drain never replays one as the newer user whatever path queued it.
      if (newToken == null ||
          !_sessionGeneration.isCurrent(generation) ||
          !_issuedUnderCurrentSession(pending.error.requestOptions)) {
        _reject(pending.handler, pending.error);
        continue;
      }

      try {
        final retryResponse = await _retryRequest(pending.error, newToken);
        pending.handler.resolve(retryResponse);
      } on Object catch (e) {
        // If retry fails, reject the pending request
        _reject(pending.handler, _asDioException(pending.error, e));
      }
    }
  }

  /// Logs out the user by clearing all authentication data.
  ///
  /// Clears the tokens, the cached user blob and the HTTP response cache, so
  /// this forced logout leaves exactly the state `AuthRepository.logout()`
  /// leaves. Clearing only the tokens used to leave a user blob behind that
  /// `isAuthenticated()` read as a live session with no token to send, and
  /// leaving the response cache behind let bodies cached before the session
  /// ended outlive it on the path the user does not control.
  ///
  /// The last step tells the **running app**. Storage is what the next launch
  /// reads; the in-memory session is what this launch renders, and once
  /// nothing dropped it, so the authenticated shell stayed up with no
  /// credentials behind it. The app is told *after* storage is emptied, so any
  /// listener reacting to the state change (the router guard, a screen
  /// refetching) already sees a device with no session on it.
  ///
  /// Each step is guarded separately and no step is reachable only through
  /// another: cleanup must never stop a handler from being completed, and a
  /// failure - or absence - of one step must not skip the rest.
  ///
  /// The teardown is registered with the [SessionGeneration] before anything
  /// else, so a sign-in - even one a session listener starts - waits for it
  /// rather than storing credentials these steps would then delete. The
  /// generation is then advanced, synchronously, ahead of every `await` in
  /// [_tearDownSession], so anything still in flight for the ending session -
  /// a refresh, a token write - is already stale by the time it reaches its
  /// own check, rather than racing the teardown it is about to undo.
  Future<void> _logoutUser() {
    final done = Completer<void>();
    _sessionGeneration.trackTeardown(done.future);
    final teardown = _tearDownSession();
    done.complete(teardown);
    return teardown;
  }

  Future<void> _tearDownSession() async {
    // Nothing in flight may write a credential for the session being ended.
    // Unguarded on purpose: it is a synchronous integer increment that cannot
    // throw, and a try/catch here would suggest it might.
    _sessionGeneration.invalidate();

    // Clear tokens from secure storage
    try {
      await _tokenStore.clearAllTokens().timeout(_teardownStepTimeout);
    } on Object catch (_) {
      // Never let cleanup failure stop a handler from being completed.
    }

    // Clear the cached user from non-sensitive storage
    final keyValueStore = _keyValueStore;
    if (keyValueStore != null) {
      try {
        await keyValueStore
            .remove(AppConstants.userDataKey)
            .timeout(_teardownStepTimeout);
      } on Object catch (_) {
        // Same reason as above: cleanup is best-effort, completion is not.
      }
    }

    // Drop cached response bodies: they are local session state too.
    //
    // Guarded rather than early-returned. An `if (x == null) return;` here
    // reads harmlessly while this is the last step and silently skips every
    // step added after it - which is exactly a bug this once had.
    final responseCache = _responseCache;
    if (responseCache != null) {
      try {
        await responseCache.clearCache().timeout(_teardownStepTimeout);
      } on Object catch (_) {
        // Same reason again. A cache that cannot be emptied must not strand
        // the 401 that triggered this logout.
      }
    }

    // Tell the running app its session is over, so the UI stops presenting it.
    final sessionSink = _sessionSink;
    if (sessionSink != null) {
      try {
        sessionSink.onSessionTerminated();
      } on Object catch (_) {
        // Deliberately swallowed, and load-bearing: a background request can
        // 401 after the app's ProviderContainer is gone, and resolving a
        // disposed provider throws. There is no in-memory session left to
        // clear in that case, and the request's handler must still complete.
      }
    }
  }
}
