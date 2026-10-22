// ApiClient.patch and per-request cancellation.
//
// The facade had get/post/put/delete only, though NetworkMethod.patch exists,
// and no way to cancel a request, though AuthInterceptor already threads the
// request's CancelToken into its replay. These drive the fully assembled
// ApiClient through a fake transport.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/request_cancellation.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Records every request that reaches the transport and replies from a
/// script; the last entry repeats.
///
/// [onHit] runs before the reply, with the 1-based hit number. A reply of
/// null holds the request open until dio cancels it.
class _Transport implements HttpClientAdapter {
  _Transport(this._statuses, {this.onHit});

  final List<int?> _statuses;
  final void Function(int hit)? onHit;
  final List<RequestOptions> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    onHit?.call(sent.length);
    final index = sent.length <= _statuses.length
        ? sent.length - 1
        : _statuses.length - 1;
    final status = _statuses[index];
    if (status == null) {
      await cancelFuture;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'held request cancelled',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'method': options.method}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final Matcher _isCancelled = isA<NetworkException>().having(
  (e) => e.code,
  'code',
  'REQUEST_CANCELLED',
);

Future<Object?> _thrownBy(Future<Object?> future) async {
  try {
    await future;
    return null;
  } on Object catch (e) {
    return e;
  }
}

void main() {
  late InMemoryTokenStore tokens;

  setUp(() {
    tokens = InMemoryTokenStore()
      ..accessToken = 'access'
      ..refreshToken = 'refresh';
  });

  ApiClient build(
    _Transport transport, {
    Future<Result<String>> Function()? refreshToken,
  }) {
    return ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: tokens,
        refreshToken: refreshToken ?? () async => const Success('fresh'),
      ),
    )..dio.httpClientAdapter = transport;
  }

  test('criterion 1: patch sends a PATCH through the full chain', () async {
    final transport = _Transport([200]);
    final client = build(transport);

    final response = await client.patch('/tasks/1', data: {'title': 'x'});

    expect(response.statusCode, 200);
    expect(transport.sent.single.method, 'PATCH');
    expect(transport.sent.single.data, {'title': 'x'});
    expect(
      transport.sent.single.headers['Authorization'],
      'Bearer access',
      reason: 'the interceptor chain ran',
    );
  });

  group('criterion 2: cancellation', () {
    test('every verb accepts the handle; cancelled up front, nothing is '
        'sent', () async {
      final transport = _Transport([200]);
      final client = build(transport);
      final cancellation = RequestCancellation()..cancel();

      final calls = <String, Future<Object?>>{
        'get': client.get('/x', cancellation: cancellation),
        'post': client.post('/x', cancellation: cancellation),
        'put': client.put('/x', cancellation: cancellation),
        'patch': client.patch('/x', cancellation: cancellation),
        'delete': client.delete('/x', cancellation: cancellation),
      };

      for (final MapEntry(key: verb, value: call) in calls.entries) {
        expect(await _thrownBy(call), _isCancelled, reason: verb);
      }
      expect(transport.sent, isEmpty);
    });

    test('cancelling an in-flight request completes the caller with a '
        'cancellation', () async {
      final cancellation = RequestCancellation();
      final transport = _Transport([null], onHit: (_) => cancellation.cancel());
      final client = build(transport);

      final thrown = await _thrownBy(
        client
            .get('/slow', cancellation: cancellation)
            .timeout(const Duration(seconds: 5)),
      );

      expect(thrown, _isCancelled);
      expect(transport.sent, hasLength(1));
    });

    test('a cancel during the retry backoff stops the re-send reaching the '
        'transport', () async {
      final cancellation = RequestCancellation();
      // 503 is retried for a GET; cancel as the first attempt is answered.
      final transport = _Transport([503], onHit: (_) => cancellation.cancel());
      final client = build(transport);

      final thrown = await _thrownBy(
        client
            .get('/flaky', cancellation: cancellation)
            .timeout(const Duration(seconds: 30)),
      );

      expect(thrown, _isCancelled);
      expect(transport.sent, hasLength(1), reason: 'no retry was sent');
    });

    test('a cancel during a 401 refresh stops the replay reaching the '
        'transport', () async {
      final cancellation = RequestCancellation();
      final transport = _Transport([401, 200]);
      var refreshes = 0;
      final client = build(
        transport,
        refreshToken: () async {
          refreshes++;
          cancellation.cancel();
          return const Success('fresh');
        },
      );

      final thrown = await _thrownBy(
        client
            .get('/me', cancellation: cancellation)
            .timeout(const Duration(seconds: 5)),
      );

      expect(refreshes, 1, reason: 'the refresh did run');
      expect(thrown, _isCancelled);
      expect(transport.sent, hasLength(1), reason: 'no replay was sent');
    });

    test('a handle that is never cancelled changes nothing', () async {
      final transport = _Transport([200]);
      final client = build(transport);

      final response = await client.get(
        '/x',
        cancellation: RequestCancellation(),
      );

      expect(response.statusCode, 200);
      expect(transport.sent, hasLength(1));
    });
  });
}
