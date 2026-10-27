import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/utils/result.dart';

/// Mixin for repository performance monitoring
///
/// This mixin provides convenient methods for tracking repository operations
/// with performance monitoring.
///
/// Usage - override [performanceService] with a real service, or the mixin
/// traces nothing (its default is `null`). A class takes a mixin with `with`
/// before `implements`:
///
/// ```dart
/// // compile
/// import 'package:flutter_starter/core/performance/i_performance_service.dart';
/// import 'package:flutter_starter/core/performance/performance_repository_mixin.dart';
/// import 'package:flutter_starter/core/utils/result.dart';
///
/// abstract class ItemsRepository {
///   Future<Result<List<String>>> getItems();
/// }
///
/// class ItemsRepositoryImpl
///     with PerformanceRepositoryMixin
///     implements ItemsRepository {
///   ItemsRepositoryImpl({required IPerformanceService performanceService})
///     : _performanceService = performanceService;
///
///   final IPerformanceService _performanceService;
///
///   // The override that makes tracing happen.
///   @override
///   IPerformanceService get performanceService => _performanceService;
///
///   @override
///   Future<Result<List<String>>> getItems() {
///     return measureRepositoryOperation(
///       operationName: 'get_items',
///       operation: () async {
///         // Your repository logic
///         return const Success(<String>['item']);
///       },
///     );
///   }
/// }
/// ```
mixin PerformanceRepositoryMixin {
  /// Get the performance service instance
  /// Override this to provide the service
  IPerformanceService? get performanceService => null;

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
      return await operation();
    }

    final operationAttributes = <String, String>{
      PerformanceAttributes.operationName: operationName,
      ...?attributes,
    };

    // No try/catch around measureOperation. It awaits `operation` inside
    // itself, so a catch here cannot tell "instrumentation threw" from "the
    // wrapped operation threw" - and re-running `operation` in the fallback
    // turned every transient failure of a non-idempotent write into a
    // duplicate write. Same class of bug as the RetryInterceptor replaying
    // non-idempotent HTTP methods. Instrumentation failures propagate to the
    // caller instead of being papered over with a second execution.
    final result = await service.measureOperation<Result<T>>(
      name: 'repository_$operationName',
      operation: operation,
      attributes: operationAttributes,
    );

    final failure = result.failureOrNull;
    if (failure != null) {
      // startTrace only creates a trace; it does not start it. A trace that
      // is never started and never stopped is never reported, so start and
      // stop it here.
      final trace = service.startTrace('repository_${operationName}_error');
      if (trace != null) {
        trace
          ..startSync()
          ..putAttribute(
            PerformanceAttributes.errorType,
            failure.runtimeType.toString(),
          )
          ..stopSync();
      }
    }

    return result;
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

    return await measureRepositoryOperation<T>(
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

    return await measureRepositoryOperation<T>(
      operationName: operationName,
      operation: operation,
      attributes: saveAttributes,
    );
  }
}
