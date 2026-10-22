// CacheConfig.maxAge must decide when the network is asked again.
//
// An entry older than maxAge but younger than maxStale was served straight
// from the cache with no network attempt, so a user saw data up to seven
// days old while online. Now a stale entry is refetched and served only if
// that fetch fails for transport reasons. These tests drive the assembled
// ApiClient (anonymous, so the cache applies) and count transport hits.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/date_formatter.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Replies from a script: an HTTP status, or a [DioExceptionType] to throw.
/// The last entry repeats. Each 200 body carries its hit number.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._script);

  final List<Object> _script;
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final step = _script[hits < _script.length ? hits : _script.length - 1];
    hits++;
    if (step is DioExceptionType) {
      throw DioException(requestOptions: options, type: step);
    }
    return ResponseBody.fromString(
      jsonEncode({'hit': hits}),
      step as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryStorage storage;

  ({ApiClient client, _ScriptedAdapter adapter}) build(
    List<Object> script, {
    CacheConfig? cacheConfig,
  }) {
    final adapter = _ScriptedAdapter(script);
    final client = ApiClient(
      storageService: storage,
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      ),
      cacheConfig: cacheConfig,
    )..dio.httpClientAdapter = adapter;
    return (client: client, adapter: adapter);
  }

  /// Makes every cached entry [age] old.
  void ageCache(Duration age) {
    final stamp = DateFormatter.formatIso8601(DateTime.now().subtract(age));
    for (final key in storage.values.keys.toList()) {
      if (key.startsWith('http_cache_timestamp_')) storage.values[key] = stamp;
    }
  }

  setUp(() => storage = InMemoryStorage());

  group('criterion 1: an entry older than maxAge goes back to the network', () {
    test('a stale entry is refetched, and the fresh answer is served and '
        'cached', () async {
      final h = build([200, 200]);
      await h.client.get('/feed');
      ageCache(const Duration(hours: 2));

      final response = await h.client.get('/feed');

      expect(h.adapter.hits, 2);
      expect(response.data, {'hit': 2});

      // The refetch replaced the entry: it is fresh again.
      final again = await h.client.get('/feed');
      expect(h.adapter.hits, 2);
      expect(again.data, {'hit': 2});
    });

    for (final failure in <Object>[
      DioExceptionType.connectionError,
      DioExceptionType.receiveTimeout,
      503,
    ]) {
      test(
        'a stale entry is served when the refetch fails with $failure',
        () async {
          final h = build([200, failure]);
          await h.client.get('/feed');
          ageCache(const Duration(hours: 2));

          final response = await h.client.get('/feed');

          expect(h.adapter.hits, 2, reason: 'the network must be asked first');
          expect(response.data, {'hit': 1});
        },
      );
    }

    test('a 4xx from the refetch is the answer, not the stale entry', () async {
      final h = build([200, 404]);
      await h.client.get('/feed');
      ageCache(const Duration(hours: 2));

      await expectLater(
        h.client.get('/feed'),
        throwsA(isA<ServerException>().having((e) => e.statusCode, 's', 404)),
      );
      expect(h.adapter.hits, 2);
    });

    test(
      'an entry younger than maxAge is served without a network hit',
      () async {
        final h = build([200]);
        await h.client.get('/feed');
        ageCache(const Duration(minutes: 30));

        final response = await h.client.get('/feed');

        expect(h.adapter.hits, 1);
        expect(response.data, {'hit': 1});
      },
    );

    test('an entry older than maxStale is gone even as a fallback', () async {
      final h = build([200, DioExceptionType.connectionError]);
      await h.client.get('/feed');
      ageCache(const Duration(days: 8));

      await expectLater(
        h.client.get('/feed'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('criterion 2: ApiClient forwards a CacheConfig', () {
    test('a non-default maxAge takes effect', () async {
      // Two minutes old: fresh under the default one hour, stale under one
      // minute.
      final defaults = build([200, 200]);
      await defaults.client.get('/feed');
      ageCache(const Duration(minutes: 2));
      await defaults.client.get('/feed');
      expect(defaults.adapter.hits, 1);

      storage = InMemoryStorage();
      final short = build([
        200,
        200,
      ], cacheConfig: const CacheConfig(maxAge: Duration(minutes: 1)));
      await short.client.get('/feed');
      ageCache(const Duration(minutes: 2));
      await short.client.get('/feed');
      expect(short.adapter.hits, 2);
    });

    test('enableCache: false bypasses the cache entirely', () async {
      final h = build([
        200,
        200,
      ], cacheConfig: const CacheConfig(enableCache: false));
      await h.client.get('/feed');
      await h.client.get('/feed');
      expect(h.adapter.hits, 2);
    });
  });
}
