import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
import 'package:flutter_starter/core/utils/result.dart';

/// Mixin for repository performance monitoring
///
/// This mixin provides convenient methods for tracking repository operations
/// with performance monitoring.
///
/// Usage:
/// ```dart
/// class MyRepositoryImpl
///     implements MyRepository with PerformanceRepositoryMixin {
///   MyRepositoryImpl({
///     required PerformanceService performanceService,
///   }) : _performanceService = performanceService;
///
///   final PerformanceService _performanceService;
///
///   @override
///   Future<Result<List<Item>>> getItems() async {
///     return measureRepositoryOperation(
///       operationName: 'get_items',
///       operation: () async {
///         // Your repository logic
///         return Success(items);
///       },
///     );
///   }
/// }
/// ```
mixin PerformanceRepositoryMixin {
  /// Get the performance service instance
  /// Override this to provide the service
  PerformanceService? get performanceService => null;

  /// Measure a repository operation with automatic performance tracking
  ///
  /// This method automatically:
  /// - Creates a trace for the operation
  /// - Records success/error metrics
  /// - Adds operation name as attribute
  ///
  /// [operationName] - Name of the operation (e.g., 'get_items', 'save_user')
  /// [operation] - The repository operation to measure
  /// [attributes] - Optional additional attributes
  /// Returns the result of the operation
  Future<Result<T>> measureRepositoryOperation<T>({
    required String operationName,
    required Future<Result<T>> Function() operation,
    Map<String, String>? attributes,
  }) async {
    final service = performanceService;
    if (service == null || !service.isEnabled) {
      return operation();
    }

    final operationAttributes = <String, String>{
      PerformanceAttributes.operationName: operationName,
      ...?attributes,
    };

    try {
      final result = await service.measureOperation<Result<T>>(
        name: 'repository_$operationName',
        operation: operation,
        attributes: operationAttributes,
      );

      // Record success/error based on result
      if (result.isSuccess) {
        // Success is already recorded by measureOperation
      } else {
        // Error is already recorded by measureOperation
        final failure = result.failureOrNull;
        if (failure != null) {
          final trace = service.startTrace('repository_$operationName');
          if (trace != null) {
            trace.putAttribute(
              PerformanceAttributes.errorType,
              failure.runtimeType.toString(),
            );
          }
        }
      }

      return result;
    } on Exception {
      // If measureOperation throws, just execute the operation
      return operation();
    }
  }

  /// Measure a data fetching operation
  ///
  /// This is a convenience method specifically for data fetching operations.
  ///
  /// [operationName] - Name of the operation
  /// [operation] - The data fetching operation
  /// [recordCount] - Optional number of records fetched
  /// [attributes] - Optional additional attributes
  Future<Result<T>> measureDataFetch<T>({
    required String operationName,
    required Future<Result<T>> Function() operation,
    int? recordCount,
    Map<String, String>? attributes,
  }) async {
    final fetchAttributes = <String, String>{
      PerformanceAttributes.queryType: 'fetch',
      if (recordCount != null)
        PerformanceAttributes.recordCount: recordCount.toString(),
      ...?attributes,
    };

    return measureRepositoryOperation<T>(
      operationName: operationName,
      operation: operation,
      attributes: fetchAttributes,
    );
  }

  /// Measure a data saving operation
  ///
  /// This is a convenience method specifically for data saving operations.
  ///
  /// [operationName] - Name of the operation
  /// [operation] - The data saving operation
  /// [attributes] - Optional additional attributes
  Future<Result<T>> measureDataSave<T>({
    required String operationName,
    required Future<Result<T>> Function() operation,
    Map<String, String>? attributes,
  }) async {
    final saveAttributes = <String, String>{
      PerformanceAttributes.queryType: 'save',
      ...?attributes,
    };

    return measureRepositoryOperation<T>(
      operationName: operationName,
      operation: operation,
      attributes: saveAttributes,
    );
  }
}
