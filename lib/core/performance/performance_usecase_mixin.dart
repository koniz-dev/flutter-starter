import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/utils/result.dart';

/// Mixin for use case performance monitoring
///
/// This mixin provides convenient methods for tracking use case operations
/// with performance monitoring.
///
/// Usage:
/// ```dart
/// class GetItemsUseCase with PerformanceUseCaseMixin {
///   GetItemsUseCase({
///     required this.repository,
///     PerformanceService? performanceService,
///   }) : _performanceService = performanceService;
///
///   final Repository repository;
///   final PerformanceService? _performanceService;
///
///   @override
///   PerformanceService? get performanceService => _performanceService;
///
///   Future<Result<List<Item>>> call() async {
///     return measureUseCaseOperation(
///       operationName: 'get_items',
///       operation: () => repository.getItems(),
///     );
///   }
/// }
/// ```
mixin PerformanceUseCaseMixin {
  /// Get the performance service instance
  /// Override this to provide the service
  IPerformanceService? get performanceService => null;

  /// Measure a use case operation with automatic performance tracking
  ///
  /// This method automatically:
  /// - Creates a trace for the operation
  /// - Records success/error metrics
  /// - Adds operation name as attribute
  ///
  /// [operationName] - Name of the operation (e.g., 'get_items', 'login')
  /// [operation] - The use case operation to measure
  /// [attributes] - Optional additional attributes
  /// Returns the result of the operation
  Future<Result<T>> measureUseCaseOperation<T>({
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
      PerformanceAttributes.operationType: 'usecase',
      ...?attributes,
    };

    // No try/catch around measureOperation. It awaits `operation` inside
    // itself, so a catch here cannot tell "instrumentation threw" from "the
    // wrapped operation threw" - and re-running `operation` in the fallback
    // executed the use case twice. Instrumentation failures propagate to the
    // caller instead of being papered over with a second execution.
    final result = await service.measureOperation<Result<T>>(
      name: 'usecase_$operationName',
      operation: operation,
      attributes: operationAttributes,
    );

    final failure = result.failureOrNull;
    if (failure != null) {
      // startTrace only creates a trace; it does not start it. A trace that
      // is never started and never stopped is never reported, so start and
      // stop it here.
      final trace = service.startTrace('usecase_${operationName}_error');
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
}
