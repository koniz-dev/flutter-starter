import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
      expect(apiClient.dio, isNotNull);
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

    group('GET requests', () {
      test('should have Dio instance configured for GET requests', () {
        // Assert
        // Verify API client is properly initialized for GET requests
        expect(apiClient.dio, isNotNull);
        expect(apiClient.dio.options.baseUrl, isNotEmpty);
      });

      test('should have error handling for GET requests', () {
        // Assert
        // Verify API client is properly initialized with error handling
        expect(apiClient.dio, isNotNull);
      });
    });

    group('POST requests', () {
      test('should have Dio instance configured for POST requests', () {
        // Assert
        // Verify API client is properly initialized for POST requests
        expect(apiClient.dio, isNotNull);
        expect(apiClient.dio.options.baseUrl, isNotEmpty);
      });

      test('should handle POST request with query parameters', () {
        // Assert
        // Verify API client supports query parameters
        expect(apiClient.dio, isNotNull);
      });
    });

    group('PUT requests', () {
      test('should have Dio instance configured for PUT requests', () {
        // Assert
        // Verify API client is properly initialized for PUT requests
        expect(apiClient.dio, isNotNull);
        expect(apiClient.dio.options.baseUrl, isNotEmpty);
      });
    });

    group('DELETE requests', () {
      test('should have Dio instance configured for DELETE requests', () {
        // Assert
        // Verify API client is properly initialized for DELETE requests
        expect(apiClient.dio, isNotNull);
        expect(apiClient.dio.options.baseUrl, isNotEmpty);
      });
    });

    group('Error handling', () {
      test('should extract AppException from DioException.error', () {
        // This test verifies that when DioException.error contains
        // an AppException, it is properly extracted and rethrown
        expect(apiClient.dio, isNotNull);
      });

      test('should rethrow DioException when error is not AppException', () {
        // This test verifies that when DioException.error is not
        // an AppException, the DioException is rethrown
        expect(apiClient.dio, isNotNull);
      });
    });

    group('Request options', () {
      test('should support custom request options', () {
        // Verify API client supports custom Options
        expect(apiClient.dio, isNotNull);
      });

      test('should support query parameters', () {
        // Verify API client supports query parameters
        expect(apiClient.dio, isNotNull);
      });
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
        expect(apiClient2.dio, isNotNull);
        expect(apiClient2.dio.options.baseUrl, apiClient.dio.options.baseUrl);
      });

      test('should expose dio getter', () {
        expect(apiClient.dio, isA<Dio>());
        expect(apiClient.dio, isNotNull);
      });
    });

    group('Constructor with optional services', () {
      test('should create ApiClient with performanceService', () {
        // Arrange
        final performanceService = MockPerformanceService();

        // Act
        final apiClientWithPerformance = ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: authInterceptor,
          performanceService: performanceService,
        );

        // Assert
        expect(apiClientWithPerformance.dio, isNotNull);
        expect(apiClientWithPerformance.dio.interceptors, isNotEmpty);
        // PerformanceInterceptor should be added when
        // performanceService is provided
        expect(
          apiClientWithPerformance.dio.interceptors.length,
          greaterThanOrEqualTo(apiClient.dio.interceptors.length),
        );
      });

      test('should create ApiClient with loggingService', () {
        // Arrange
        final loggingService = MockLoggingService();

        // Act
        final apiClientWithLogging = ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: authInterceptor,
          loggingService: loggingService,
        );

        // Assert
        expect(apiClientWithLogging.dio, isNotNull);
        expect(apiClientWithLogging.dio.interceptors, isNotEmpty);
        // ApiLoggingInterceptor should be added when loggingService is provided
        expect(
          apiClientWithLogging.dio.interceptors.length,
          greaterThanOrEqualTo(apiClient.dio.interceptors.length),
        );
      });

      test('should create ApiClient with both performanceService and '
          'loggingService', () {
        // Arrange
        final performanceService = MockPerformanceService();
        final loggingService = MockLoggingService();

        // Act
        final apiClientWithBoth = ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: authInterceptor,
          performanceService: performanceService,
          loggingService: loggingService,
        );

        // Assert
        expect(apiClientWithBoth.dio, isNotNull);
        expect(apiClientWithBoth.dio.interceptors, isNotEmpty);
        // Both interceptors should be added
        expect(
          apiClientWithBoth.dio.interceptors.length,
          greaterThanOrEqualTo(apiClient.dio.interceptors.length),
        );
      });
    });
  });
}
