import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';
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

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import '/Users/nguyenanhkiet/Playground/flutter-starter/test/helpers/in_memory_stores.dart';
import 'dart:typed_data';

/// Pending request data structure for queuing requests during token refresh
class _PendingRequest {
  _PendingRequest(this.error, this.handler);

  final DioException error;
  final ErrorInterceptorHandler handler;
}

/// Interceptor for adding authentication tokens to requests and handling
/// automatic token refresh on 401 Unauthorized responses
class BaselineAuthInterceptor extends Interceptor {
  /// Creates an [BaselineAuthInterceptor] with the given dependencies
  BaselineAuthInterceptor({
    ITokenStore? tokenStore,
    SecureStorageService? secureStorageService,
    required Future<Result<String>> Function() refreshToken,
    Dio Function()? retryDioFactory,
    IKeyValueStore? keyValueStore,
    ISessionTerminationSink? sessionSink,
    SessionGeneration? sessionGeneration,
  }) : _retryDioFactory = retryDioFactory,
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
      // order: a replay resolved from onError ends the host chain, so only
      // these see its response. ApiLoggingInterceptor redacts the replay's
      // fresh Authorization header like any other.
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
    // no `BaselineAuthInterceptor`, so a replay answered 401 cannot re-enter this
    // method - it surfaces from `_retryRequest` below and logs out there.

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
      // and the `finally` drain still replays the queued requests.
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
    // Catches Error as well as Exception on purpose: a TypeError from a
    // malformed refresh response must not leave _isRefreshing stuck true.
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
  /// In dio's error chain, a bare `handler.reject(error)` skips every
  /// interceptor registered after this one - `RetryInterceptor`,
  /// `ApiLoggingInterceptor` and `ErrorInterceptor` in `ApiClient` - so the
  /// 401 would reach the caller unlogged and unmapped. `next` hands it on
  /// (on every dio 5.x, with no flag a later edit could drop), so it is
  /// logged and mapped like any other failing status. Every failure exit in
  /// this class goes through here.
  ///
  /// Forwarded, but **never re-sent**. The error is marked with
  /// [RetryInterceptor.retryExtraKey] `= false` before it moves on, so
  /// `RetryInterceptor` passes it through instead of replaying it. Every exit
  /// that reaches here has already ended the request's session or given up on
  /// it, and a failed replay's options carry the bearer token minted for the
  /// session that was just torn down, which must not go back on the wire.
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
  /// leaves: a leftover blob would read as a session with no token, and
  /// leftover cached bodies would outlive the session.
  ///
  /// The last step tells the **running app**, which renders the in-memory
  /// session, *after* storage is emptied, so any listener reacting to the
  /// change (the router guard, a screen refetching) already sees a device
  /// with no session on it.
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
      await _tokenStore.clearAllTokens();
    } on Object catch (_) {
      // Never let cleanup failure stop a handler from being completed.
    }

    // Clear the cached user from non-sensitive storage
    final keyValueStore = _keyValueStore;
    if (keyValueStore != null) {
      try {
        await keyValueStore.remove(AppConstants.userDataKey);
      } on Object catch (_) {
        // Same reason as above: cleanup is best-effort, completion is not.
      }
    }

    // Drop cached response bodies: they are local session state too.
    //
    // Guarded rather than early-returned, so a step added after this one is
    // never skipped.
    final responseCache = _responseCache;
    if (responseCache != null) {
      try {
        await responseCache.clearCache();
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

class ProbeAdapter implements HttpClientAdapter {
  ProbeAdapter(this.valid);
  final String? valid;
  final bearers = <Object?>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    bearers.add(options.headers['Authorization']);
    return ResponseBody.fromString('{}', options.headers['Authorization'] == valid ? 200 : 401);
  }
  @override
  void close({bool force = false}) {}
}
void main() {
  registerBaselineBoundaryCases();
  initialSelectionProbes();
  for(final baseline in [true, false]) {
    test('${baseline ? 'baseline' : 'current'} custom refresher persists only refresh token', () async {
      final tokens = InMemoryTokenStore()..accessToken='A1'..refreshToken='R1';
      final replay = ProbeAdapter('Bearer A2');
      Future<Result<String>> refresh() async {
        await tokens.setRefreshToken('R2');
        return const Success('A2');
      }
      final Interceptor auth = baseline
        ? BaselineAuthInterceptor(tokenStore:tokens,refreshToken:refresh,retryDioFactory:()=>Dio()..httpClientAdapter=replay)
        : AuthInterceptor(tokenStore:tokens,refreshToken:refresh,retryDioFactory:()=>Dio()..httpClientAdapter=replay);
      final dio=Dio(BaseOptions(baseUrl:'https://example.invalid'))..httpClientAdapter=ProbeAdapter(null)..interceptors.add(auth);
      Object? outcome;
      try {outcome=await dio.get<dynamic>('/profile');} on Object catch(e) {outcome=e;}
      print('baseline=$baseline outcome=${outcome.runtimeType} replay=${replay.bearers} access=${tokens.accessToken} refresh=${tokens.refreshToken}');
      dio.close(force:true);
      if(baseline) {
        expect(outcome,isA<Response<dynamic>>());
        expect(tokens.accessToken,'A2');
        expect(replay.bearers,['Bearer A2']);
      } else {
        expect(outcome,isA<DioException>());
        expect((outcome as DioException).type,DioExceptionType.cancel);
        expect(tokens.accessToken,'A1');
        expect(replay.bearers,isEmpty);
      }
      expect(tokens.refreshToken,'R2');
    });
  }
}

class _SecureService extends Mock implements SecureStorageService {}

class _Tokens extends InMemoryTokenStore {
  final writes = <String>[];
  int clears = 0;
  Object? snapshotError;
  void Function()? afterSnapshot;
  AccessTokenWriteResult? forcedConditional;
  void Function()? afterConditional;

  @override
  Future<void> clearAllTokens() {
    clears++;
    return super.clearAllTokens();
  }

  @override
  Future<AccessTokenSnapshot?> getAccessTokenSnapshot() async {
    final snapshot = await super.getAccessTokenSnapshot();
    final hook = afterSnapshot;
    afterSnapshot = null;
    hook?.call();
    final error = snapshotError;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
    return snapshot;
  }

  int reads = 0;
  int? holdRead;
  final readEntered = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<String?> getAccessToken() async {
    final snapshot = await super.getAccessToken();
    if (++reads == holdRead) {
      readEntered.complete();
      await releaseRead.future;
    }
    return snapshot;
  }

  @override
  Future<AccessTokenWriteResult> setAccessTokenIfCurrent(
    AccessTokenSnapshot expected,
    String token,
  ) async {
    final forced = forcedConditional;
    if (forced != null) {
      // A failed reservation still changes revision. A conflict is modeled
      // by another actor replacing the credentials before this comparison.
      if (forced == AccessTokenWriteResult.conflict) {
        accessToken = 'external';
        refreshToken = 'external-refresh';
      } else {
        await trackCredentialMutation<void>(() {});
      }
      final hook = afterConditional;
      if (hook != null) scheduleMicrotask(hook);
      return forced;
    }
    final outcome = await super.setAccessTokenIfCurrent(expected, token);
    if (outcome == AccessTokenWriteResult.applied) writes.add(token);
    return outcome;
  }

  @override
  Future<bool> setAccessToken(String token) {
    writes.add(token);
    return super.setAccessToken(token);
  }
}

class _RotatingRemote implements AuthRemoteDataSource {
  int rotation = 1;
  String Function(int)? accessForRotation;
  String get currentAccess => accessForRotation?.call(rotation) ?? 'A$rotation';

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    expect(refreshToken, 'R$rotation');
    rotation++;
    return AuthResponseModel(
      user: const UserModel(id: 'u', email: 'u@example.test'),
      token: currentAccess,
      refreshToken: 'R$rotation',
    );
  }

  @override
  Future<void> logout({String? refreshToken, String? accessToken}) async {}

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final int Function(RequestOptions) status;
  final bearers = <Object?>[];
  final entered = Completer<void>();
  Completer<void>? release;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bearers.add(options.headers['Authorization']);
    if (!entered.isCompleted) entered.complete();
    if (release != null) await release!.future;
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      status(options),
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ObservedInterceptor extends BaselineAuthInterceptor {
  _ObservedInterceptor({
    required super.tokenStore,
    required super.refreshToken,
    required super.sessionGeneration,
    required super.retryDioFactory,
    super.keyValueStore,
  });

  final secondError = Completer<void>();
  int errors = 0;

  @override
  Future<void> onError(DioException error, ErrorInterceptorHandler handler) {
    final handling = super.onError(error, handler);
    if (++errors == 2) secondError.complete();
    return handling;
  }
}

Future<Object> _settle(Future<Response<dynamic>> request) async {
  try {
    return await request;
  } on Object catch (error) {
    return error;
  }
}

Future<T> _within<T>(Future<T> future) =>
    future.timeout(const Duration(seconds: 5));

void registerBaselineBoundaryCases() {
  late _Tokens tokens;
  late InMemoryKeyValueStore preferences;
  late SessionGeneration generation;
  late _RotatingRemote remote;
  late AuthRepositoryImpl repository;
  late _Adapter original;
  late _Adapter replay;

  setUp(() {
    tokens = _Tokens()
      ..accessToken = 'A1'
      ..refreshToken = 'R1';
    preferences = InMemoryKeyValueStore();
    generation = SessionGeneration();
    remote = _RotatingRemote();
    repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(
        storageService: preferences,
        tokenStore: tokens,
      ),
      sessionGeneration: generation,
    );
    original = _Adapter((_) => 401);
    replay = _Adapter(
      (options) =>
          options.headers['Authorization'] == 'Bearer ${remote.currentAccess}'
          ? 200
          : 401,
    );
  });

  ({Dio dio, _ObservedInterceptor interceptor}) client(
    Future<Result<String>> Function() refresh, {
    ITokenStore? store,
  }) {
    final interceptor = _ObservedInterceptor(
      tokenStore: store ?? tokens,
      keyValueStore: preferences,
      sessionGeneration: generation,
      refreshToken: refresh,
      retryDioFactory: () => Dio()..httpClientAdapter = replay,
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = original
      ..interceptors.add(interceptor);
    addTearDown(() {
      interceptor.dispose();
      dio.close(force: true);
    });
    return (dio: dio, interceptor: interceptor);
  }

  test(
    'delayed repository callback preserves a later rotation for all replays',
    () async {
      final callbackReady = Completer<void>();
      final releaseCallback = Completer<void>();
      final pair = client(() async {
        final result = await repository.refreshToken();
        callbackReady.complete();
        await releaseCallback.future;
        return result;
      });
      final first = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(callbackReady.future);
      final second = _settle(pair.dio.get<dynamic>('/tasks'));
      await _within(pair.interceptor.secondError.future);

      expect((await repository.refreshToken()).isSuccess, isTrue);
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      releaseCallback.complete();
      final outcomes = await _within(Future.wait([first, second]));

      expect(tokens.writes, ['A2', 'A3'], reason: 'no late duplicate A2 write');
      expect(replay.bearers, ['Bearer A3', 'Bearer A3']);
      expect(
        outcomes.every((value) => value is Response && value.statusCode == 200),
        isTrue,
      );
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
    },
  );

  test(
    'a callback that only returns a token is still persisted and replayed',
    () async {
      replay = _Adapter((_) => 200);
      final pair = client(() async => const Success('A2'));
      final response = await _within(pair.dio.get<dynamic>('/profile'));
      expect(response.statusCode, 200);
      expect(tokens.writes, ['A2']);
      expect(tokens.accessToken, 'A2');
      expect(replay.bearers, ['Bearer A2']);
    },
  );

  test(
    'a rotation before the callback starts does not suppress its new result',
    () async {
      original.release = Completer<void>();
      replay = _Adapter((_) => 200);
      final pair = client(() async => const Success('A3'));
      final pending = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(original.entered.future);
      await tokens.setAccessToken('A2');
      original.release!.complete();
      expect(await _within(pending), isA<Response<dynamic>>());
      expect(tokens.accessToken, 'A3');
      expect(tokens.writes, ['A2', 'A3']);
      expect(replay.bearers, ['Bearer A3']);
    },
  );

  test('a repository-persisted refresh is not written a second time', () async {
    final pair = client(repository.refreshToken);
    final response = await _within(pair.dio.get<dynamic>('/profile'));
    expect(response.statusCode, 200);
    expect(tokens.writes, ['A2']);
    expect(tokens.refreshToken, 'R2');
    expect(replay.bearers, ['Bearer A2']);
  });
  test('ABA rotations preserve the newer access/refresh pairing', () async {
    remote.accessForRotation = (rotation) =>
        rotation == 3 ? 'A1' : 'A$rotation';
    final ready = Completer<void>();
    final release = Completer<void>();
    final pair = client(() async {
      final result = await repository.refreshToken();
      ready.complete();
      await release.future;
      return result;
    });
    final pending = _settle(pair.dio.get<dynamic>('/profile'));
    await _within(ready.future);
    expect((await repository.refreshToken()).isSuccess, isTrue);
    expect(tokens.accessToken, 'A1');
    release.complete();
    expect(await _within(pending), isA<Response<dynamic>>());
    expect(tokens.writes, ['A2', 'A1']);
    expect(tokens.refreshToken, 'R3');
    expect(replay.bearers, ['Bearer A1']);
  });

  test(
    'a stale held snapshot read never replays or deletes a newer rotation',
    () async {
      tokens.holdRead = 2;
      final pair = client(repository.refreshToken);
      final pending = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(tokens.readEntered.future);
      expect((await repository.refreshToken()).isSuccess, isTrue);
      tokens.releaseRead.complete();
      final outcome = await _within(pending);
      expect(outcome, isA<DioException>());
      expect((outcome as DioException).type, DioExceptionType.cancel);
      expect(tokens.writes, ['A2', 'A3']);
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test('a new session during snapshot selection is untouched', () async {
    tokens.holdRead = 2;
    final pair = client(() async => const Success('A2'));
    final pending = _settle(pair.dio.get<dynamic>('/profile'));
    await _within(tokens.readEntered.future);
    generation.invalidate();
    await tokens.setAccessToken('different-user');
    await tokens.setRefreshToken('different-refresh');
    tokens.releaseRead.complete();
    expect(await _within(pending), isA<DioException>());
    expect(tokens.accessToken, 'different-user');
    expect(tokens.refreshToken, 'different-refresh');
    expect(tokens.clears, 0);
    expect(replay.bearers, isEmpty);
  });

  test(
    'a revision changed after certification is rechecked before dispatch',
    () async {
      tokens.afterSnapshot = () {
        tokens
          ..accessToken = 'external'
          ..refreshToken = 'external-refresh';
      };
      final pair = client(() async => const Success('A2'));
      expect(
        await _within(_settle(pair.dio.get<dynamic>('/profile'))),
        isA<DioException>(),
      );
      expect(tokens.accessToken, 'external');
      expect(tokens.refreshToken, 'external-refresh');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test('conditional conflict rejects without replay or teardown', () async {
    tokens.forcedConditional = AccessTokenWriteResult.conflict;
    final pair = client(() async => const Success('A2'));
    expect(
      await _within(_settle(pair.dio.get<dynamic>('/profile'))),
      isA<DioException>(),
    );
    expect(tokens.accessToken, 'external');
    expect(tokens.refreshToken, 'external-refresh');
    expect(tokens.clears, 0);
    expect(replay.bearers, isEmpty);
  });

  test(
    'a failed adoption cannot delete credentials installed after its result',
    () async {
      tokens.forcedConditional = AccessTokenWriteResult.failed;
      tokens.afterConditional = () {
        tokens
          ..accessToken = 'external'
          ..refreshToken = 'external-refresh';
      };
      final pair = client(() async => const Success('A2'));
      expect(
        await _within(_settle(pair.dio.get<dynamic>('/profile'))),
        isA<DioException>(),
      );
      expect(tokens.accessToken, 'external');
      expect(tokens.refreshToken, 'external-refresh');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test(
    'a snapshot read error after success preserves the newer stored session',
    () async {
      final pair = client(() async {
        final result = await repository.refreshToken();
        expect((await repository.refreshToken()).isSuccess, isTrue);
        tokens.snapshotError = StateError('platform read failed');
        return result;
      });
      expect(
        await _within(_settle(pair.dio.get<dynamic>('/profile'))),
        isA<DioException>(),
      );
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      expect(tokens.clears, 0);
      expect(replay.bearers, isEmpty);
    },
  );

  test(
    'a later rotation during replay survives its old 401 and feeds the queue',
    () async {
      replay.release = Completer<void>();
      final pair = client(repository.refreshToken);
      final first = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(replay.entered.future);
      final second = _settle(pair.dio.get<dynamic>('/tasks'));
      await _within(pair.interceptor.secondError.future);
      expect((await repository.refreshToken()).isSuccess, isTrue);
      replay.release!.complete();
      final outcomes = await _within(Future.wait([first, second]));
      expect(outcomes.first, isA<DioException>());
      expect(outcomes.last, isA<Response<dynamic>>());
      expect(replay.bearers, ['Bearer A2', 'Bearer A3']);
      expect(tokens.accessToken, 'A3');
      expect(tokens.refreshToken, 'R3');
      expect(tokens.clears, 0);
    },
  );
  test(
    'the secure adapter refuses a timed out stale snapshot after rotation',
    () async {
      final service = _SecureService();
      final values = <String, String>{
        AppConstants.tokenKey: 'A1',
        AppConstants.refreshTokenKey: 'R1',
      };
      final readEntered = Completer<void>();
      final releaseRead = Completer<void>();
      var accessReads = 0;
      var removals = 0;
      when(() => service.getStringOrThrow(any())).thenAnswer((call) async {
        final key = call.positionalArguments[0] as String;
        final captured = values[key];
        if (key == AppConstants.tokenKey && ++accessReads == 2) {
          readEntered.complete();
          await releaseRead.future;
        }
        return captured;
      });
      when(() => service.setString(any(), any())).thenAnswer((call) async {
        values[call.positionalArguments[0] as String] =
            call.positionalArguments[1] as String;
        return true;
      });
      when(() => service.remove(any())).thenAnswer((call) async {
        removals++;
        values.remove(call.positionalArguments[0] as String);
        return true;
      });
      final store = SecureTokenStore(
        service,
        operationTimeout: const Duration(milliseconds: 5),
      );
      final realRepository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: AuthLocalDataSourceImpl(
          storageService: preferences,
          tokenStore: store,
        ),
        sessionGeneration: generation,
      );
      final pair = client(realRepository.refreshToken, store: store);
      final request = _settle(pair.dio.get<dynamic>('/profile'));
      await _within(readEntered.future);
      // Queue timeout lets the newer repository write complete while the old
      // platform read is still held. Certification must not bless its A2.
      expect((await _within(realRepository.refreshToken())).isSuccess, isTrue);
      releaseRead.complete();
      final outcome = await _within(request);
      expect(outcome, isA<DioException>());
      expect(replay.bearers, isEmpty);
      expect(values[AppConstants.tokenKey], 'A3');
      expect(values[AppConstants.refreshTokenKey], 'R3');
      expect(removals, 0);
      expect((await store.getAccessTokenSnapshot())?.token, 'A3');
    },
  );
}

class InitialSnapshotTokens extends InMemoryTokenStore {
  InitialSnapshotTokens(this.throwError);
  final bool throwError;
  final entered=Completer<void>();
  final release=Completer<void>();
  int clears=0;
  @override Future<AccessTokenSnapshot?> getAccessTokenSnapshot() async {
    entered.complete();
    await release.future;
    if(throwError) throw StateError('initial read error');
    return null;
  }
  @override Future<void> clearAllTokens() {clears++; return super.clearAllTokens();}
}
class InitialObservedAuth extends AuthInterceptor {
  InitialObservedAuth({required super.tokenStore,required super.refreshToken,required super.retryDioFactory});
  final secondError=Completer<void>();
  int errors=0;
  @override Future<void> onError(DioException e,ErrorInterceptorHandler h) {
    final future=super.onError(e,h);
    if(++errors==2) secondError.complete();
    return future;
  }
}
void initialSelectionProbes() {
  for(final throwError in [false,true]) {
    test('followup initial snapshot ${throwError ? "error" : "uncertainty"} rejects original and queue without cleanup',() async {
      final tokens=InitialSnapshotTokens(throwError)..accessToken='A1'..refreshToken='R1';
      var calls=0;
      final replay=ProbeAdapter('Bearer A2');
      final auth=InitialObservedAuth(tokenStore:tokens,refreshToken:() async {calls++;return const Success('A2');},retryDioFactory:()=>Dio()..httpClientAdapter=replay);
      final dio=Dio(BaseOptions(baseUrl:'https://example.invalid'))..httpClientAdapter=ProbeAdapter(null)..interceptors.add(auth);
      final first=_settle(dio.get<dynamic>('/first'));
      await tokens.entered.future.timeout(const Duration(seconds:5));
      final second=_settle(dio.get<dynamic>('/second'));
      await auth.secondError.future.timeout(const Duration(seconds:5));
      tokens.release.complete();
      final results=await Future.wait([first,second]).timeout(const Duration(seconds:5));
      print('initialThrow=$throwError results=${results.map((e)=>e.runtimeType).toList()} callbackCalls=$calls clears=${tokens.clears} replay=${replay.bearers}');
      expect(results,everyElement(isA<DioException>()));
      expect(calls,0);expect(tokens.clears,0);expect(tokens.accessToken,'A1');expect(tokens.refreshToken,'R1');expect(replay.bearers,isEmpty);
      auth.dispose();dio.close(force:true);
    });
  }
}
