import 'package:flutter_starter/core/performance/performance_service.dart';

/// Performance monitoring utilities
///
/// Provides helper functions and extensions for common performance monitoring
/// patterns.
class PerformanceUtils {
  PerformanceUtils._();

  /// Measure API call performance
  ///
  /// This is a convenience method that wraps an API call with performance
  /// tracking. It automatically:
  /// - Creates a trace with the API endpoint name
  /// - Records success/error metrics
  /// - Adds HTTP method and path as attributes
  ///
  /// Usage:
  /// ```dart
  /// final result = await PerformanceUtils.measureApiCall(
  ///   service: performanceService,
  ///   method: 'GET',
  ///   path: '/users',
  ///   call: () => apiClient.get('/users'),
  /// );
  /// ```
  static Future<T> measureApiCall<T>({
    required PerformanceService service,
    required String method,
    required String path,
    required Future<T> Function() call,
    Map<String, String>? additionalAttributes,
  }) async {
    final attributes = <String, String>{
      'http_method': method,
      'http_path': path,
      if (additionalAttributes != null) ...additionalAttributes,
    };

    return service.measureOperation<T>(
      name: 'api_${method.toLowerCase()}_${_sanitizePath(path)}',
      operation: call,
      attributes: attributes,
    );
  }

  /// Measure database query performance
  ///
  /// This is a convenience method that wraps a database query with performance
  /// tracking.
  ///
  /// Usage:
  /// ```dart
  /// final users = await PerformanceUtils.measureDatabaseQuery(
  ///   service: performanceService,
  ///   queryName: 'get_users',
  ///   query: () => database.getUsers(),
  /// );
  /// ```
  static Future<T> measureDatabaseQuery<T>({
    required PerformanceService service,
    required String queryName,
    required Future<T> Function() query,
    Map<String, String>? attributes,
  }) async {
    final queryAttributes = <String, String>{
      'query_name': queryName,
      if (attributes != null) ...attributes,
    };

    return service.measureOperation<T>(
      name: 'db_query_$queryName',
      operation: query,
      attributes: queryAttributes,
    );
  }

  /// Measure heavy computation performance
  ///
  /// This is a convenience method that wraps a heavy computation with
  /// performance tracking.
  ///
  /// Usage:
  /// ```dart
  /// final result = await PerformanceUtils.measureComputation(
  ///   service: performanceService,
  ///   operationName: 'image_processing',
  ///   computation: () => processImage(image),
  /// );
  /// ```
  static Future<T> measureComputation<T>({
    required PerformanceService service,
    required String operationName,
    required Future<T> Function() computation,
    Map<String, String>? attributes,
  }) async {
    return service.measureOperation<T>(
      name: 'computation_$operationName',
      operation: computation,
      attributes: attributes,
    );
  }

  /// Measure sync computation performance
  ///
  /// This is a convenience method that wraps a sync computation with
  /// performance tracking.
  ///
  /// Usage:
  /// ```dart
  /// final result = PerformanceUtils.measureSyncComputation(
  ///   service: performanceService,
  ///   operationName: 'data_parsing',
  ///   computation: () => parseJson(jsonString),
  /// );
  /// ```
  static T measureSyncComputation<T>({
    required PerformanceService service,
    required String operationName,
    required T Function() computation,
    Map<String, String>? attributes,
  }) {
    return service.measureSyncOperation<T>(
      name: 'computation_$operationName',
      operation: computation,
      attributes: attributes,
    );
  }

  /// Sanitize path to avoid creating too many unique traces
  static String _sanitizePath(String path) {
    // Remove query parameters
    final withoutQuery = path.split('?').first;
    // Replace common ID patterns with placeholders
    return withoutQuery
        .replaceAll(RegExp(r'/\d+'), '/:id')
        .replaceAll(RegExp('/[a-f0-9-]{36}'), '/:uuid')
        .replaceAll(RegExp('/[a-zA-Z0-9]{20,}'), '/:token');
  }
}

/// Extension on [PerformanceService] for convenience methods
extension PerformanceServiceExtension on PerformanceService {
  /// Measure an API call
  Future<T> measureApiCall<T>({
    required String method,
    required String path,
    required Future<T> Function() call,
    Map<String, String>? attributes,
  }) {
    return PerformanceUtils.measureApiCall<T>(
      service: this,
      method: method,
      path: path,
      call: call,
      additionalAttributes: attributes,
    );
  }

  /// Measure a database query
  Future<T> measureDatabaseQuery<T>({
    required String queryName,
    required Future<T> Function() query,
    Map<String, String>? attributes,
  }) {
    return PerformanceUtils.measureDatabaseQuery<T>(
      service: this,
      queryName: queryName,
      query: query,
      attributes: attributes,
    );
  }

  /// Measure a computation
  Future<T> measureComputation<T>({
    required String operationName,
    required Future<T> Function() computation,
    Map<String, String>? attributes,
  }) {
    return PerformanceUtils.measureComputation<T>(
      service: this,
      operationName: operationName,
      computation: computation,
      attributes: attributes,
    );
  }
}
