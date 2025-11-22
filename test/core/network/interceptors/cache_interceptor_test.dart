import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageService extends Mock implements StorageService {}

/// Test handler for request interceptor
class TestRequestInterceptorHandler extends RequestInterceptorHandler {
  TestRequestInterceptorHandler() : super();

  Response<dynamic>? resolvedResponse;

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingResponseInterceptor = true,
  ]) {
    resolvedResponse = response;
  }
}

/// Test handler for response interceptor
class TestResponseInterceptorHandler extends ResponseInterceptorHandler {
  TestResponseInterceptorHandler() : super();
}

void main() {
  group('CacheInterceptor', () {
    late CacheInterceptor interceptor;
    late MockStorageService mockStorageService;
    late RequestOptions requestOptions;

    setUp(() {
      mockStorageService = MockStorageService();
      interceptor = CacheInterceptor(
        storageService: mockStorageService,
      );
      requestOptions = RequestOptions(
        path: '/api/test',
        method: 'GET',
        baseUrl: 'https://api.example.com',
      );

      // Register fallback values
      registerFallbackValue('');
    });

    group('onRequest', () {
      test('should return cached response when available and valid', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        const cacheKey = 'http_cache_https://api.example.com/api/test_{}';
        const timestampKey = 'http_cache_timestamp_$cacheKey';
        const cachedData = '{"key": "value"}';
        final timestamp = DateTime.now().subtract(const Duration(minutes: 30));

        when(() => mockStorageService.getString(cacheKey))
            .thenAnswer((_) async => cachedData);
        when(() => mockStorageService.getString(timestampKey))
            .thenAnswer((_) async => timestamp.toIso8601String());

        // Act
        await interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(handler.resolvedResponse, isNotNull);
        expect(handler.resolvedResponse?.statusCode, 200);
        expect(handler.resolvedResponse?.data, {'key': 'value'});
      });

      test('should not cache non-GET requests', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final postOptions = RequestOptions(
          path: '/api/test',
          method: 'POST',
        );

        // Act
        await interceptor.onRequest(postOptions, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
        verifyNever(() => mockStorageService.getString(any()));
      });

      test('should bypass cache when cache-control header is no-cache',
          () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithNoCache = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'cache-control': 'no-cache'},
        );

        // Act
        await interceptor.onRequest(optionsWithNoCache, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
        verifyNever(() => mockStorageService.getString(any()));
      });

      test('should bypass cache when cache-control header is no-store',
          () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithNoStore = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'cache-control': 'no-store'},
        );

        // Act
        await interceptor.onRequest(optionsWithNoStore, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
        verifyNever(() => mockStorageService.getString(any()));
      });

      test('should bypass cache when authorization header is present',
          () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithAuth = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'authorization': 'Bearer token'},
        );

        // Act
        await interceptor.onRequest(optionsWithAuth, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
        verifyNever(() => mockStorageService.getString(any()));
      });

      test('should bypass cache when cookie header is present', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithCookie = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'cookie': 'session=abc123'},
        );

        // Act
        await interceptor.onRequest(optionsWithCookie, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
        verifyNever(() => mockStorageService.getString(any()));
      });

      test('should return null when cache is not found', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        const cacheKey = 'http_cache_https://api.example.com/api/test_{}';

        when(() => mockStorageService.getString(cacheKey))
            .thenAnswer((_) async => null);

        // Act
        await interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
      });

      test('should return null when timestamp is not found', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        const cacheKey = 'http_cache_https://api.example.com/api/test_{}';
        const timestampKey = 'http_cache_timestamp_$cacheKey';
        const cachedData = '{"key": "value"}';

        when(() => mockStorageService.getString(cacheKey))
            .thenAnswer((_) async => cachedData);
        when(() => mockStorageService.getString(timestampKey))
            .thenAnswer((_) async => null);

        // Act
        await interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
      });

      test('should remove expired cache when too stale', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        const cacheKey = 'http_cache_https://api.example.com/api/test_{}';
        const timestampKey = 'http_cache_timestamp_$cacheKey';
        const cachedData = '{"key": "value"}';
        final oldTimestamp = DateTime.now()
            .subtract(const Duration(days: 8)); // Older than maxStale (7 days)

        when(() => mockStorageService.getString(cacheKey))
            .thenAnswer((_) async => cachedData);
        when(() => mockStorageService.getString(timestampKey))
            .thenAnswer((_) async => oldTimestamp.toIso8601String());
        when(() => mockStorageService.remove(cacheKey))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.remove(timestampKey))
            .thenAnswer((_) async => true);

        // Act
        await interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
        verify(() => mockStorageService.remove(cacheKey)).called(1);
        verify(() => mockStorageService.remove(timestampKey)).called(1);
      });

      test('should use stale cache when within maxStale', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        const cacheKey = 'http_cache_https://api.example.com/api/test_{}';
        const timestampKey = 'http_cache_timestamp_$cacheKey';
        const cachedData = '{"key": "value"}';
        // Older than maxAge (1 hour) but within maxStale (7 days)
        final staleTimestamp = DateTime.now().subtract(const Duration(days: 2));

        when(() => mockStorageService.getString(cacheKey))
            .thenAnswer((_) async => cachedData);
        when(() => mockStorageService.getString(timestampKey))
            .thenAnswer((_) async => staleTimestamp.toIso8601String());

        // Act
        await interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(handler.resolvedResponse, isNotNull);
        verifyNever(() => mockStorageService.remove(any()));
      });
    });

    group('onResponse', () {
      test('should cache successful GET response', () async {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();
        const cacheKey = 'http_cache_https://api.example.com/api/test_{}';
        const timestampKey = 'http_cache_timestamp_$cacheKey';

        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await interceptor.onResponse(response, handler);

        // Assert
        verify(
          () => mockStorageService.setString(
            cacheKey,
            any(that: contains('key')),
          ),
        ).called(1);
        verify(
          () => mockStorageService.setString(
            timestampKey,
            any(that: isA<String>()),
          ),
        ).called(1);
      });

      test('should not cache non-GET responses', () async {
        // Arrange
        final postOptions = RequestOptions(
          path: '/api/test',
          method: 'POST',
        );
        final response = Response<dynamic>(
          requestOptions: postOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();

        // Act
        await interceptor.onResponse(response, handler);

        // Assert
        verifyNever(() => mockStorageService.setString(any(), any()));
      });

      test('should not cache non-200 responses', () async {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {'error': 'Not found'},
        );
        final handler = TestResponseInterceptorHandler();

        // Act
        await interceptor.onResponse(response, handler);

        // Assert
        verifyNever(() => mockStorageService.setString(any(), any()));
      });

      test('should not cache when cache is disabled', () async {
        // Arrange
        final interceptorWithDisabledCache = CacheInterceptor(
          storageService: mockStorageService,
          cacheConfig: const CacheConfig(enableCache: false),
        );
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();

        // Act
        await interceptorWithDisabledCache.onResponse(response, handler);

        // Assert
        verifyNever(() => mockStorageService.setString(any(), any()));
      });

      test('should handle cache write errors gracefully', () async {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();

        when(() => mockStorageService.setString(any(), any()))
            .thenThrow(Exception('Storage error'));

        // Act & Assert
        await expectLater(
          interceptor.onResponse(response, handler),
          completes,
        );
      });

      test('should include query parameters in cache key', () async {
        // Arrange
        final optionsWithQuery = RequestOptions(
          path: '/api/test',
          method: 'GET',
          queryParameters: {'page': '1', 'limit': '10'},
        );
        final response = Response<dynamic>(
          requestOptions: optionsWithQuery,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();

        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await interceptor.onResponse(response, handler);

        // Assert
        // Cache saves data and timestamp, so setString is called twice
        // Both should contain the query parameters in the key
        verify(
          () => mockStorageService.setString(
            any(that: contains('page')),
            any(),
          ),
        ).called(2);
      });
    });

    group('_shouldBypassCache', () {
      test('should bypass cache for no-cache header', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'cache-control': 'no-cache'},
        );

        // Act
        await interceptor.onRequest(options, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
      });

      test('should bypass cache for no-store header', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'cache-control': 'no-store'},
        );

        // Act
        await interceptor.onRequest(options, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
      });

      test('should bypass cache for authorization header', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'authorization': 'Bearer token'},
        );

        // Act
        await interceptor.onRequest(options, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
      });

      test('should bypass cache for cookie header', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {'cookie': 'session=abc123'},
        );

        // Act
        await interceptor.onRequest(options, handler);

        // Assert
        expect(handler.resolvedResponse, isNull);
      });
    });

    group('_getCacheKey', () {
      test('should generate cache key from URI and query parameters', () async {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'GET',
          queryParameters: {'page': '1'},
        );

        // Mock all getString calls to return null
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => null);

        // Act
        await interceptor.onRequest(options, handler);

        // Assert
        // Verify getString was called (for cache data and timestamp)
        verify(() => mockStorageService.getString(any()))
            .called(greaterThan(0));
      });
    });

    group('clearCache', () {
      test('should handle clear cache without errors', () async {
        // Act & Assert
        await expectLater(interceptor.clearCache(), completes);
      });
    });
  });
}
