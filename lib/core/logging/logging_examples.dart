/// Examples of using the logging service throughout the application
///
/// This file demonstrates how to use the logging service in different layers
/// of the Clean Architecture:
/// - Use cases (domain layer)
/// - Repositories (data layer)
/// - API client (data layer)
/// - Error handling (all layers)
///
/// These examples show best practices for structured logging with context.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/utils/result.dart';

// ============================================================================
// Example 1: Logging in Use Cases (Domain Layer)
// ============================================================================

/// Example use case with logging
///
/// Use cases should log:
/// - Entry point with input parameters (sanitized)
/// - Success outcomes
/// - Failure outcomes with context
class ExampleUseCase {
  /// Creates an [ExampleUseCase] with the given [repository] and
  /// [loggingService]
  ExampleUseCase({
    required this.repository,
    required this.loggingService,
  });

  /// Repository for data operations
  final ExampleRepository repository;

  /// Logging service for structured logging
  final LoggingService loggingService;

  /// Execute the use case with logging
  Future<Result<String>> call(String userId) async {
    // Log entry point with sanitized input
    loggingService.info(
      'ExampleUseCase: Starting execution',
      context: {
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    try {
      // Execute business logic
      final result = await repository.getData(userId);

      // Log success
      loggingService.info(
        'ExampleUseCase: Execution successful',
        context: {
          'userId': userId,
          'resultLength': result.length,
        },
      );

      return Success(result);
    } on Exception catch (e, stackTrace) {
      // Log error with full context
      loggingService.error(
        'ExampleUseCase: Execution failed',
        context: {
          'userId': userId,
          'errorType': e.runtimeType.toString(),
        },
        error: e,
        stackTrace: stackTrace,
      );

      return ResultFailure(
        UnknownFailure('Failed to execute use case: $e'),
      );
    }
  }
}

// ============================================================================
// Example 2: Logging in Repositories (Data Layer)
// ============================================================================

/// Example repository with logging
///
/// Repositories should log:
/// - Data source operations (API calls, database queries)
/// - Cache operations
/// - Data transformations
abstract class ExampleRepository {
  /// Get data for a user
  Future<String> getData(String userId);

  /// Save data for a user
  Future<void> saveData(String userId, String data);

  /// Delete data for a user
  Future<String> deleteData(String userId);
}

/// Implementation of [ExampleRepository] with logging
class ExampleRepositoryImpl implements ExampleRepository {
  /// Creates an [ExampleRepositoryImpl] with the given [remoteDataSource] and
  /// [loggingService]
  ExampleRepositoryImpl({
    required this.remoteDataSource,
    required this.loggingService,
  });

  /// Remote data source for fetching data
  final ExampleRemoteDataSource remoteDataSource;

  /// Logging service for structured logging
  final LoggingService loggingService;

  @override
  Future<String> getData(String userId) async {
    // Log data source operation
    loggingService.debug(
      'Repository: Fetching data from remote source',
      context: {
        'userId': userId,
        'dataSource': 'remote',
      },
    );

    try {
      final data = await remoteDataSource.fetchData(userId);

      // Log successful data retrieval
      loggingService.debug(
        'Repository: Data retrieved successfully',
        context: {
          'userId': userId,
          'dataSize': data.length,
        },
      );

      return data;
    } on Exception catch (e, stackTrace) {
      // Log repository error
      loggingService.error(
        'Repository: Failed to fetch data',
        context: {
          'userId': userId,
          'dataSource': 'remote',
        },
        error: e,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  @override
  Future<void> saveData(String userId, String data) async {
    loggingService.debug(
      'Repository: Saving data',
      context: {'userId': userId},
    );
    // Implementation would go here
  }

  @override
  Future<String> deleteData(String userId) async {
    loggingService.debug(
      'Repository: Deleting data',
      context: {'userId': userId},
    );
    // Implementation would go here
    return '';
  }
}

// ============================================================================
// Example 3: Logging in API Client (Data Layer)
// ============================================================================

/// Example remote data source with logging
///
/// API clients should log:
/// - Request details (method, path, headers - sanitized)
/// - Response details (status code, body - sanitized)
/// - Network errors
abstract class ExampleRemoteDataSource {
  /// Fetch data for a user
  Future<String> fetchData(String userId);

  /// Update data for a user
  Future<String> updateData(String userId, String data);

  /// Delete data for a user
  Future<void> deleteData(String userId);
}

/// Implementation of [ExampleRemoteDataSource] with logging
class ExampleRemoteDataSourceImpl implements ExampleRemoteDataSource {
  /// Creates an [ExampleRemoteDataSourceImpl] with the given [apiClient] and
  /// [loggingService]
  ExampleRemoteDataSourceImpl({
    required this.apiClient,
    required this.loggingService,
  });

  /// API client for making HTTP requests
  final ExampleApiClient apiClient;

  /// Logging service for structured logging
  final LoggingService loggingService;

  @override
  Future<String> fetchData(String userId) async {
    // Log API request
    loggingService.debug(
      'API: Making request to fetch data',
      context: {
        'endpoint': '/users/$userId/data',
        'method': 'GET',
        'userId': userId,
      },
    );

    try {
      final response = await apiClient.get('/users/$userId/data');

      // Log API response
      loggingService.info(
        'API: Request successful',
        context: {
          'endpoint': '/users/$userId/data',
          'statusCode': response.statusCode,
          'responseSize': response.data?.toString().length ?? 0,
        },
      );

      return response.data.toString();
    } on Exception catch (e, stackTrace) {
      // Log API error
      loggingService.error(
        'API: Request failed',
        context: {
          'endpoint': '/users/$userId/data',
          'method': 'GET',
        },
        error: e,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  @override
  Future<String> updateData(String userId, String data) async {
    loggingService.debug(
      'API: Making request to update data',
      context: {
        'endpoint': '/users/$userId/data',
        'method': 'PUT',
        'userId': userId,
      },
    );
    // Implementation would go here
    return '';
  }

  @override
  Future<void> deleteData(String userId) async {
    loggingService.debug(
      'API: Making request to delete data',
      context: {
        'endpoint': '/users/$userId/data',
        'method': 'DELETE',
        'userId': userId,
      },
    );
    // Implementation would go here
  }
}

// ============================================================================
// Example 4: Logging in Error Handling
// ============================================================================

/// Example error handler with logging
///
/// Error handlers should log:
/// - All caught exceptions with full context
/// - Stack traces for debugging
/// - User-friendly error messages
class ExampleErrorHandler {
  /// Creates an [ExampleErrorHandler] with the given [loggingService]
  ExampleErrorHandler({
    required this.loggingService,
  });

  /// Logging service for structured logging
  final LoggingService loggingService;

  /// Handle an error with comprehensive logging
  void handleError(
    Object error,
    StackTrace stackTrace, {
    Map<String, dynamic>? context,
  }) {
    // Log error with all available context
    loggingService.error(
      'ErrorHandler: Unhandled error occurred',
      context: {
        ...?context,
        'errorType': error.runtimeType.toString(),
        'errorMessage': error.toString(),
      },
      error: error,
      stackTrace: stackTrace,
    );

    // Additional error handling logic (e.g., send to crash reporting service)
    // if (AppConfig.enableCrashReporting) {
    //   crashReportingService.recordError(error, stackTrace, context: context);
    // }
  }

  /// Handle a warning with logging
  void handleWarning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    loggingService.warning(
      'ErrorHandler: $message',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

// ============================================================================
// Example 5: Using Logging Service with Riverpod
// ============================================================================

/// Example of accessing logging service in a widget
///
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final logger = ref.read(loggingServiceProvider);
///
///     return ElevatedButton(
///       onPressed: () {
///         logger.info('Button pressed', context: {'buttonId': 'myButton'});
///       },
///       child: Text('Press Me'),
///     );
///   }
/// }
/// ```

/// Example provider that uses logging
final exampleUseCaseProvider = Provider<ExampleUseCase>((ref) {
  final repository = ref.watch(exampleRepositoryProvider);
  final loggingService = ref.read(loggingServiceProvider);
  return ExampleUseCase(
    repository: repository,
    loggingService: loggingService,
  );
});

// Placeholder providers for examples
/// Provider for [ExampleRepository] instance
final exampleRepositoryProvider = Provider<ExampleRepository>((ref) {
  final remoteDataSource = ref.watch(exampleRemoteDataSourceProvider);
  final loggingService = ref.read(loggingServiceProvider);
  return ExampleRepositoryImpl(
    remoteDataSource: remoteDataSource,
    loggingService: loggingService,
  );
});

/// Provider for [ExampleRemoteDataSource] instance
final exampleRemoteDataSourceProvider =
    Provider<ExampleRemoteDataSource>((ref) {
  final apiClient = ref.watch(exampleApiClientProvider);
  final loggingService = ref.read(loggingServiceProvider);
  return ExampleRemoteDataSourceImpl(
    apiClient: apiClient,
    loggingService: loggingService,
  );
});

/// Provider for [ExampleApiClient] instance
final exampleApiClientProvider = Provider<ExampleApiClient>((ref) {
  return ExampleApiClient();
});

// Placeholder classes for examples
/// Placeholder API client for examples
class ExampleApiClient {
  /// Makes a GET request to the given [path]
  Future<ExampleResponse> get(String path) async {
    return ExampleResponse(statusCode: 200, data: 'example data');
  }
}

/// Placeholder response class for examples
class ExampleResponse {
  /// Creates an [ExampleResponse] with the given [statusCode] and [data]
  ExampleResponse({required this.statusCode, required this.data});

  /// HTTP status code
  final int statusCode;

  /// Response data
  final dynamic data;
}
