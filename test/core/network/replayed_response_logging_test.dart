// A refreshed-and-replayed request must be logged like any other.
//
// AuthInterceptor resolves the replay from onError, which in dio ends the
// host chain, so ApiLoggingInterceptor logged the 401 and never the 200 the
// caller received. The replay client now borrows the host's logging
// interceptor; these tests drive the assembled ApiClient and the real replay
// client, with only the transport replaced.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

const _freshToken = 'fresh-access-token-SECRET';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Records every message and context, prints nothing.
class _RecordingLoggingService extends LoggingService {
  _RecordingLoggingService() : super(enableLogging: false);

  final List<(String, Map<String, dynamic>?)> entries = [];

  @override
  void debug(String message, {Map<String, dynamic>? context}) =>
      entries.add((message, context));

  @override
  void info(String message, {Map<String, dynamic>? context}) =>
      entries.add((message, context));

  @override
  void warning(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => entries.add((message, context));

  @override
  void error(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => entries.add((message, context));
}

/// Replies from a script of statuses; the last one repeats.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._statuses);

  final List<int> _statuses;
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status =
        _statuses[hits < _statuses.length ? hits : _statuses.length - 1];
    hits++;
    return ResponseBody.fromString(
      jsonEncode({'hit': hits}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingLoggingService logging;
  late _ScriptedAdapter adapter;
  late ApiClient client;

  setUp(() {
    logging = _RecordingLoggingService();
    adapter = _ScriptedAdapter([401, 200]);
    client = ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: InMemoryTokenStore()..accessToken = 'stale-access-token',
        refreshToken: () async => const Success(_freshToken),
      ),
      loggingService: logging,
    )..dio.httpClientAdapter = adapter;
  });

  test('criterion 1: the replayed 200 is logged as a response', () async {
    final response = await client.post('/tasks', data: {'title': 'x'});

    expect(response.statusCode, 200);
    expect(adapter.hits, 2);
    expect(
      logging.entries.map((e) => e.$1),
      contains('API Response: 200 /tasks'),
    );
  });

  test('criterion 2: no logged entry carries the fresh access token', () async {
    await client.post('/tasks', data: {'title': 'x'});

    final logged = logging.entries.map((e) => '${e.$1} ${e.$2}').join('\n');
    expect(logged, isNot(contains(_freshToken)));
    expect(logged, isNot(contains('stale-access-token')));
    // The replay's request was logged too, with its header redacted.
    expect(
      logging.entries.where((e) => e.$1 == 'API Request: POST /tasks'),
      hasLength(2),
    );
  });
}
