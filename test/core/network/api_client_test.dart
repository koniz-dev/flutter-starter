import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/error_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class MockStorageService extends Mock implements StorageService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

/// Signed-out token store: `CacheInterceptor` reads the auth interceptor's
/// store to decide whether a response may be cached (#77), so the mock has to
/// expose a real one.
class StubTokenStore implements ITokenStore {
  @override
  Future<void> clearAccessToken() async {}

  @override
  Future<void> clearAllTokens() async {}

  @override
  Future<void> clearRefreshToken() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<bool> setAccessToken(String token) async => true;

  @override
  Future<bool> setRefreshToken(String token) async => true;
}

class MockAuthInterceptor extends Mock implements AuthInterceptor {
  @override
  ITokenStore get tokenStore => StubTokenStore();
}

class MockLoggingService extends Mock implements LoggingService {}

class MockPerformanceService extends Mock implements IPerformanceService {}

/// Transport that records every request and answers with [statusCode].
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200});

  final int statusCode;

  /// Every request that reached the transport, in order.
  final List<RequestOptions> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    return ResponseBody.fromString(
      jsonEncode({'ok': statusCode < 400}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient', () {
    late StorageService storageService;
    late SecureStorageService secureStorageService;
    late AuthInterceptor authInterceptor;
    late ApiClient apiClient;

    setUp(() {
      storageService = MockStorageService();
      secureStorageService = MockSecureStorageService();
      authInterceptor = MockAuthInterceptor();
      apiClient = ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: authInterceptor,
      );
    });

    test('should create Dio instance with correct configuration', () {
      // Assert
      expect(apiClient.dio.options.baseUrl, isNotEmpty);
      expect(apiClient.dio.options.connectTimeout, isNotNull);
      expect(apiClient.dio.options.receiveTimeout, isNotNull);
      expect(apiClient.dio.options.headers['Content-Type'], 'application/json');
      expect(apiClient.dio.options.headers['Accept'], 'application/json');
    });

    test('should have interceptors configured', () {
      // Assert
      expect(apiClient.dio.interceptors, isNotEmpty);
      // ErrorInterceptor terminates the error chain, so it must be last.
      expect(apiClient.dio.interceptors.last, isA<ErrorInterceptor>());
    });

    group('Dio Configuration', () {
      test('should have baseUrl with API version', () {
        final baseUrl = apiClient.dio.options.baseUrl;
        expect(baseUrl, isNotEmpty);
        expect(baseUrl, contains('/v1'));
      });

      test('should have correct timeout values', () {
        expect(apiClient.dio.options.connectTimeout, isNotNull);
        expect(apiClient.dio.options.receiveTimeout, isNotNull);
        expect(apiClient.dio.options.connectTimeout!.inSeconds, greaterThan(0));
        expect(apiClient.dio.options.receiveTimeout!.inSeconds, greaterThan(0));
      });

      test('should have correct headers', () {
        final headers = apiClient.dio.options.headers;
        expect(headers['Content-Type'], 'application/json');
        expect(headers['Accept'], 'application/json');
      });

      test('should register the concrete interceptor types in order', () {
        // dio runs BOTH onRequest and onError in registration order, and
        // ErrorInterceptor.onError calls handler.reject(), which terminates
        // the chain. It must therefore be registered last, or retry, 401
        // refresh, performance teardown and error logging never run.
        // Refs koniz-dev/flutter-starter#46.
        final interceptors = apiClient.dio.interceptors.toList();

        expect(interceptors, hasLength(5));
        // dio seeds the list with its own ImplyContentTypeInterceptor, which
        // is not exported from package:dio, hence the runtimeType check.
        expect(
          interceptors[0].runtimeType.toString(),
          'ImplyContentTypeInterceptor',
        );
        expect(interceptors[1], isA<CacheInterceptor>());
        expect(interceptors[2], same(authInterceptor));
        expect(interceptors[3], isA<RetryInterceptor>());
        expect(interceptors[4], isA<ErrorInterceptor>());
      });

      test(
        'should register logging and performance before ErrorInterceptor',
        () {
          final client = ApiClient(
            storageService: storageService,
            secureStorageService: secureStorageService,
            authInterceptor: authInterceptor,
            loggingService: MockLoggingService(),
            performanceService: MockPerformanceService(),
          );
          final interceptors = client.dio.interceptors.toList();

          expect(interceptors, hasLength(7));
          expect(
            interceptors[0].runtimeType.toString(),
            'ImplyContentTypeInterceptor',
          );
          expect(interceptors[1], isA<PerformanceInterceptor>());
          expect(interceptors[2], isA<CacheInterceptor>());
          expect(interceptors[3], same(authInterceptor));
          expect(interceptors[4], isA<RetryInterceptor>());
          expect(interceptors[5], isA<ApiLoggingInterceptor>());
          expect(interceptors[6], isA<ErrorInterceptor>());
        },
      );
    });

    group('Edge Cases', () {
      test('should handle multiple ApiClient instances', () {
        final apiClient2 = ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: authInterceptor,
        );
        expect(apiClient2.dio.options.baseUrl, apiClient.dio.options.baseUrl);
      });

      test('should expose dio getter', () {
        expect(apiClient.dio, isA<Dio>());
      });
    });
  });

  // koniz-dev/flutter-starter#369: the groups these replace only asserted that
  // the non-nullable `dio` was non-null, so they could not fail. Each test
  // below sends a real request through the real interceptor chain and asserts
  // on what reached the transport.
  group('ApiClient requests reach the transport', () {
    late _RecordingAdapter adapter;

    ApiClient buildClient({int statusCode = 200}) {
      adapter = _RecordingAdapter(statusCode: statusCode);
      return ApiClient(
        storageService: InMemoryStorage(),
        secureStorageService: MockSecureStorageService(),
        authInterceptor: AuthInterceptor(
          tokenStore: InMemoryTokenStore(),
          refreshToken: () async => const Success('unused'),
        ),
      )..dio.httpClientAdapter = adapter;
    }

    RequestOptions onlyRequest() {
      expect(adapter.sent, hasLength(1));
      return adapter.sent.single;
    }

    test('get sends GET with its path, query and headers', () async {
      final response = await buildClient().get(
        '/users',
        queryParameters: {'page': 2},
        headers: {'X-Trace': 't-1'},
      );

      final sent = onlyRequest();
      expect(sent.method, 'GET');
      expect(sent.path, '/users');
      expect(sent.queryParameters, {'page': 2});
      expect(sent.headers['X-Trace'], 't-1');
      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
    });

    test('post sends POST with its body and query', () async {
      await buildClient().post(
        '/tasks',
        data: {'title': 'Write tests'},
        queryParameters: {'notify': true},
      );

      final sent = onlyRequest();
      expect(sent.method, 'POST');
      expect(sent.path, '/tasks');
      expect(sent.data, {'title': 'Write tests'});
      expect(sent.queryParameters, {'notify': true});
    });

    test('put sends PUT with its body', () async {
      await buildClient().put('/tasks/1', data: {'title': 'Renamed'});

      final sent = onlyRequest();
      expect(sent.method, 'PUT');
      expect(sent.path, '/tasks/1');
      expect(sent.data, {'title': 'Renamed'});
    });

    test('delete sends DELETE with its query', () async {
      await buildClient().delete('/tasks/1', queryParameters: {'hard': true});

      final sent = onlyRequest();
      expect(sent.method, 'DELETE');
      expect(sent.path, '/tasks/1');
      expect(sent.queryParameters, {'hard': true});
    });

    test('a 4xx surfaces as a ServerException carrying the status code, '
        'never as a DioException', () async {
      final client = buildClient(statusCode: 404);

      await expectLater(
        client.get('/missing'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });
}
