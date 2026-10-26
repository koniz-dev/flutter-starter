// A request that is sent again - replayed after a 401 refresh, or retried
// after a transient failure - must go out with the same per-request options
// as the original. Both paths rebuild an `Options` by hand, and each field
// left out silently falls back to the client default: transformTimeout,
// followRedirects and maxRedirects were dropped that way.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Replies from a script (an HTTP status, or a [DioExceptionType] to throw)
/// and keeps the [RequestOptions] of every request that reached it.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._script);

  final List<Object> _script;
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final step =
        _script[sent.length < _script.length
            ? sent.length
            : _script.length - 1];
    sent.add(options);
    if (step is DioExceptionType) {
      throw DioException(requestOptions: options, type: step);
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      step as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

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

void main() {
  late _MockStorageService storage;

  setUp(() {
    storage = _MockStorageService();
    // CacheInterceptor reads storage on GET; a miss lets the request out.
    when(() => storage.getString(any())).thenAnswer((_) async => null);
  });

  ({ApiClient client, _RecordingAdapter adapter}) build(List<Object> script) {
    final adapter = _RecordingAdapter(script);
    final client = ApiClient(
      storageService: storage,
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: _InMemoryTokenStore(),
        refreshToken: () async => const Success('fresh-access-token'),
      ),
      retryInitialDelay: Duration.zero,
      retryMaxJitter: Duration.zero,
    )..dio.httpClientAdapter = adapter;
    return (client: client, adapter: adapter);
  }

  final custom = Options(
    transformTimeout: const Duration(seconds: 7),
    followRedirects: false,
    maxRedirects: 2,
  );

  void expectCarried(RequestOptions sent) {
    expect(sent.transformTimeout, const Duration(seconds: 7));
    expect(sent.followRedirects, isFalse);
    expect(sent.maxRedirects, 2);
  }

  test('a client-wide transformTimeout reaches the replay after a 401 '
      'refresh', () async {
    final h = build([401, 200]);
    h.client.dio.options.transformTimeout = const Duration(seconds: 9);

    final response = await h.client.dio.get<dynamic>('/tasks');

    expect(response.statusCode, 200);
    expect(h.adapter.sent, hasLength(2), reason: 'the request, then replay');
    expect(h.adapter.sent.last.transformTimeout, const Duration(seconds: 9));
  });

  test('per-request options reach the replay after a 401 refresh', () async {
    final h = build([401, 200]);

    await h.client.dio.get<dynamic>('/tasks', options: custom);

    expect(h.adapter.sent, hasLength(2));
    expectCarried(h.adapter.sent.first);
    expectCarried(h.adapter.sent.last);
  });

  test(
    'per-request options reach the retry after a transient failure',
    () async {
      final h = build([DioExceptionType.connectionError, 200]);

      await h.client.dio.get<dynamic>('/tasks', options: custom);

      expect(h.adapter.sent, hasLength(2), reason: 'the request, then retry');
      expectCarried(h.adapter.sent.first);
      expectCarried(h.adapter.sent.last);
    },
  );
}
