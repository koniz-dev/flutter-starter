import 'package:flutter_starter/core/performance/i_performance_service.dart';

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
    required IPerformanceService service,
    required String method,
    required String path,
    required Future<T> Function() call,
    Map<String, String>? additionalAttributes,
  }) async {
    final attributes = <String, String>{
      'http_method': method,
      'http_path': path,
      ...?additionalAttributes,
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
    required IPerformanceService service,
    required String queryName,
    required Future<T> Function() query,
    Map<String, String>? attributes,
  }) async {
    final queryAttributes = <String, String>{
      'query_name': queryName,
      ...?attributes,
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
    required IPerformanceService service,
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
    required IPerformanceService service,
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

  /// A whole path segment shaped like an RFC 4122 UUID.
  static final RegExp _uuidSegment = RegExp(
    '/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
    r'-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(?=/|$)',
  );

  /// A whole path segment long enough to be an opaque token.
  ///
  /// Deliberately excludes `-` and `_` so a long but human-readable route
  /// segment such as `/user-profile-settings` is left alone.
  static final RegExp _tokenSegment = RegExp(r'/[a-zA-Z0-9]{20,}(?=/|$)');

  /// A whole path segment that is only digits.
  static final RegExp _numericIdSegment = RegExp(r'/\d+(?=/|$)');

  /// Sanitize path to avoid creating too many unique traces
  ///
  /// The order matters. Applying the numeric-id rule first mangled any UUID
  /// that begins with a digit - roughly 62% of v4 UUIDs - into
  /// `/:ide8400-e29b-...`, which is still unique per UUID and so still blew
  /// through the backend's cap on distinct custom traces. Most specific
  /// pattern first: UUID, then opaque token, then bare numeric id.
  ///
  /// Every pattern matches a **whole** segment, so a partial match inside a
  /// longer segment cannot rewrite it.
  static String _sanitizePath(String path) {
    // Remove query parameters
    final withoutQuery = path.split('?').first;
    return withoutQuery
        .replaceAll(_uuidSegment, '/:uuid')
        .replaceAll(_tokenSegment, '/:token')
        .replaceAll(_numericIdSegment, '/:id');
  }
}

/// Extension on [IPerformanceService] for convenience methods
extension PerformanceServiceExtension on IPerformanceService {
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
