// The access token belongs to the API's origin. An absolute URL elsewhere - a
// presigned upload, a CDN, a pagination link from another host - must not
// receive it, and that host's 401 must not refresh or end the session.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Records every request's URL and `Authorization` header, and answers each
/// with [statusCode].
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode);

  final int statusCode;
  final List<(Uri, Object?)> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add((options.uri, options.headers['Authorization']));
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _foreign = 'https://uploads.thirdparty.example/bucket/obj?sig=abc';

void main() {
  late InMemoryTokenStore store;
  late SessionGeneration generation;
  late int refreshCalls;
  late _RecordingAdapter adapter;
  late ApiClient client;

  void build(int statusCode) {
    adapter = _RecordingAdapter(statusCode);
    client = ApiClient(
      storageService: _MockStorageService(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: store,
        sessionGeneration: generation,
        refreshToken: () async {
          refreshCalls++;
          return const Success('refreshed-token');
        },
      ),
      retryInitialDelay: Duration.zero,
      retryMaxJitter: Duration.zero,
    )..dio.httpClientAdapter = adapter;
  }

  setUp(() {
    store = InMemoryTokenStore()
      ..accessToken = 'access-token'
      ..refreshToken = 'refresh-token';
    generation = SessionGeneration();
    refreshCalls = 0;
  });

  test('a foreign-origin absolute URL is sent without the token', () async {
    build(200);

    await client.put(_foreign, data: 'bytes');

    expect(adapter.sent.single.$1.host, 'uploads.thirdparty.example');
    expect(adapter.sent.single.$2, isNull);
  });

  test('an absolute URL on the API origin carries the token', () async {
    build(200);
    final sameOrigin = '${client.dio.options.baseUrl}/me';
    expect(Uri.parse(sameOrigin).hasScheme, isTrue);

    await client.get(sameOrigin);

    expect(adapter.sent.single.$2, 'Bearer access-token');
  });

  test('a relative path carries the token', () async {
    build(200);

    await client.get('/me');

    expect(adapter.sent.single.$2, 'Bearer access-token');
  });

  test('a foreign-origin 401 neither refreshes nor clears the session, and '
      'reaches the caller as a 401', () async {
    build(401);
    final before = generation.current;

    Object? thrown;
    try {
      await client.get(_foreign);
    } on Object catch (e) {
      thrown = e;
    }

    expect(thrown, isNotNull);
    expect(refreshCalls, 0);
    expect(adapter.sent, hasLength(1));
    expect(store.accessToken, 'access-token');
    expect(store.refreshToken, 'refresh-token');
    expect(generation.current, before);
  });

  test('a header the caller set on a foreign-origin request is kept', () async {
    build(200);

    await client.get(
      _foreign,
      headers: {'Authorization': 'Basic partner-creds'},
    );

    expect(adapter.sent.single.$2, 'Basic partner-creds');
  });

  // dio joins a relative path to the base URL as strings. With a base URL
  // that has no path, a path starting with `@` or `.` moves the host.
  group('a base URL with no path', () {
    late Dio dio;

    void buildBare(int statusCode) {
      adapter = _RecordingAdapter(statusCode);
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          AuthInterceptor(
            tokenStore: store,
            sessionGeneration: generation,
            refreshToken: () async {
              refreshCalls++;
              return const Success('refreshed-token');
            },
          ),
        );
    }

    for (final (path, host) in [
      ('@evil.example/x', 'evil.example'),
      ('.evil.example/x', 'api.example.com.evil.example'),
    ]) {
      test('$path lands on $host and is sent without the token', () async {
        buildBare(200);

        await dio.get<dynamic>(path);

        expect(adapter.sent.single.$1.host, host);
        expect(adapter.sent.single.$2, isNull);
      });

      test("$path's 401 is not refreshed", () async {
        buildBare(401);

        await expectLater(dio.get<dynamic>(path), throwsA(isA<DioException>()));

        expect(refreshCalls, 0);
        expect(adapter.sent, hasLength(1));
        expect(store.accessToken, 'access-token');
      });
    }

    test('an ordinary path on it carries the token', () async {
      buildBare(200);

      await dio.get<dynamic>('/x');

      expect(adapter.sent.single.$1.host, 'api.example.com');
      expect(adapter.sent.single.$2, 'Bearer access-token');
    });
  });

  test('an API-origin 401 still refreshes once and replays', () async {
    build(401);

    try {
      await client.get('/me');
    } on Object catch (_) {
      // The fake answers the replay 401 too; only the refresh matters here.
    }

    expect(refreshCalls, 1);
    expect(adapter.sent.last.$2, 'Bearer refreshed-token');
  });
}
