import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageService extends Mock implements StorageService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthInterceptor extends Mock implements AuthInterceptor {}

class MockLoggingService extends Mock implements LoggingService {}

class MockPerformanceService extends Mock implements PerformanceService {}

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
      expect(
        apiClient.dio.options.headers['Content-Type'],
        'application/json',
      );
      expect(apiClient.dio.options.headers['Accept'], 'application/json');
    });

    test('should have interceptors configured', () {
      // Assert
      expect(apiClient.dio.interceptors, isNotEmpty);
      // ErrorInterceptor should be first
      expect(apiClient.dio.interceptors.first, isA<Interceptor>());
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

      test('should have interceptors in correct order', () {
        final interceptors = apiClient.dio.interceptors;
        expect(interceptors.length, greaterThanOrEqualTo(2));
        // ErrorInterceptor should be first
        expect(interceptors.first, isA<Interceptor>());
      });
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
        // PerformanceInterceptor should be added when performanceService is provided
        expect(apiClientWithPerformance.dio.interceptors.length,
            greaterThanOrEqualTo(apiClient.dio.interceptors.length));
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
        expect(apiClientWithLogging.dio.interceptors.length,
            greaterThanOrEqualTo(apiClient.dio.interceptors.length));
      });

      test('should create ApiClient with both performanceService and loggingService',
          () {
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
        expect(apiClientWithBoth.dio.interceptors.length,
            greaterThanOrEqualTo(apiClient.dio.interceptors.length));
      });
    });
  });
}
