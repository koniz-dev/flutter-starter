// A failed 401 head replay is not a failed refresh
// (koniz-dev/flutter-starter#304).
//
// AuthInterceptor used to replay the original request inside the same `try`
// as the refresh. When the refresh succeeded but the replay then hit a
// transient failure, the catch logged the user out - destroying the token it
// had just stored - and the `finally` drain rejected every queued request
// with 401 instead of replaying it with the fresh token.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _InMemoryTokenStore implements ITokenStore {
  String? accessToken = 'expired-access-token';
  String? refreshToken = 'refresh-token';

  @override
  Future<void> clearAccessToken() async => accessToken = null;

  @override
  Future<void> clearAllTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<void> clearRefreshToken() async => refreshToken = null;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> setAccessToken(String token) async {
    accessToken = token;
    return true;
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }
}

class _CountingSessionSink implements ISessionTerminationSink {
  int calls = 0;

  @override
  void onSessionTerminated() => calls++;
}

/// Answers 401 to the expired token, and [freshReply] for the fresh one.
class _TokenAwareAdapter implements HttpClientAdapter {
  _TokenAwareAdapter(this.freshReply);

  /// Status for a request carrying `Bearer fresh`, by path.
  final int Function(String path) freshReply;

  final List<String> wire = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    wire.add('${options.path} $auth');
    final status = auth == 'Bearer fresh' ? freshReply(options.path) : 401;
    return ResponseBody.fromString(
      jsonEncode({'path': options.path, 'message': 'status $status'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// An [AuthInterceptor] whose [seen] completes after `count` 401s are parked.
class _CountingAuthInterceptor extends AuthInterceptor {
  _CountingAuthInterceptor({
    required super.refreshToken,
    super.tokenStore,
    super.sessionSink,
  });

  int errorsSeen = 0;
  final Map<int, Completer<void>> _marks = {};

  Future<void> seen(int count) => errorsSeen >= count
      ? Future<void>.value()
      : (_marks[count] ??= Completer<void>()).future;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) {
    final handled = super.onError(err, handler);
    errorsSeen++;
    final mark = _marks[errorsSeen];
    if (mark != null && !mark.isCompleted) mark.complete();
    return handled;
  }
}

Future<Object?> _thrownBy(Future<Object?> future) async {
  try {
    await future;
    return null;
  } on Object catch (e) {
    return e;
  }
}

void main() {
  late _MockStorageService storageService;
  late _MockSecureStorageService secureStorageService;
  late _InMemoryTokenStore tokenStore;
  late _CountingSessionSink sink;

  setUp(() {
    storageService = _MockStorageService();
    secureStorageService = _MockSecureStorageService();
    tokenStore = _InMemoryTokenStore();
    sink = _CountingSessionSink();
    // A forced logout empties the response cache, which walks its index.
    when(
      () => storageService.getStringList(any()),
    ).thenAnswer((_) async => null);
    when(() => storageService.remove(any())).thenAnswer((_) async => true);
  });

  ApiClient clientWith(AuthInterceptor auth, _TokenAwareAdapter adapter) =>
      ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: auth,
      )..dio.httpClientAdapter = adapter;

  test('criterion 1: refresh OK, head replay 503 - the caller gets the 503, '
      'the fresh token is kept, the session sink is not called', () async {
    final adapter = _TokenAwareAdapter((_) => 503);
    final apiClient = clientWith(
      AuthInterceptor(
        tokenStore: tokenStore,
        sessionSink: sink,
        refreshToken: () async => const Success('fresh'),
      ),
      adapter,
    );

    final thrown = await _thrownBy(apiClient.post('/a', data: {'x': 1}));

    expect(
      thrown,
      isA<ServerException>().having((e) => e.statusCode, 'statusCode', 503),
    );
    expect(tokenStore.accessToken, 'fresh');
    expect(tokenStore.refreshToken, 'refresh-token');
    expect(sink.calls, 0);
    expect(adapter.wire, ['/a Bearer expired-access-token', '/a Bearer fresh']);
  });

  test('criterion 2: a request queued behind the same refresh is still '
      'replayed with the fresh token and resolves', () async {
    final adapter = _TokenAwareAdapter((path) => path == '/a' ? 503 : 200);
    final release = Completer<void>();
    final auth = _CountingAuthInterceptor(
      tokenStore: tokenStore,
      sessionSink: sink,
      refreshToken: () async {
        await release.future;
        return const Success('fresh');
      },
    );
    final apiClient = clientWith(auth, adapter);

    final head = _thrownBy(apiClient.post('/a', data: {'x': 1}));
    final queued = apiClient.post('/b', data: {'x': 2});
    await auth.seen(2);
    release.complete();

    final queuedResponse = await queued;
    final headError = await head;

    expect(
      headError,
      isA<ServerException>().having((e) => e.statusCode, 'statusCode', 503),
    );
    expect(queuedResponse.statusCode, 200);
    expect(adapter.wire, contains('/b Bearer fresh'));
    expect(tokenStore.accessToken, 'fresh');
    expect(sink.calls, 0);
  });

  test('criterion 3: a head replay that itself returns 401 still forces the '
      'logout', () async {
    final adapter = _TokenAwareAdapter((_) => 401);
    final apiClient = clientWith(
      AuthInterceptor(
        tokenStore: tokenStore,
        sessionSink: sink,
        refreshToken: () async => const Success('fresh'),
      ),
      adapter,
    );

    final thrown = await _thrownBy(apiClient.post('/a', data: {'x': 1}));

    expect(
      thrown,
      isA<ServerException>().having((e) => e.statusCode, 'statusCode', 401),
    );
    expect(tokenStore.accessToken, isNull);
    expect(tokenStore.refreshToken, isNull);
    expect(sink.calls, 1);
  });
}
