import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
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
  PerformanceService? get performanceService => null;

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

    try {
      final result = await service.measureOperation<Result<T>>(
        name: 'usecase_$operationName',
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
          final trace = service.startTrace('usecase_$operationName');
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
}
