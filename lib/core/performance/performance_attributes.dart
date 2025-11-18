/// Common performance attribute keys
///
/// This class provides constants for commonly used performance attribute keys
/// to ensure consistency across the application.
class PerformanceAttributes {
  PerformanceAttributes._();

  // HTTP attributes
  /// HTTP method attribute key (e.g., 'GET', 'POST')
  static const String httpMethod = 'http_method';

  /// HTTP path attribute key
  static const String httpPath = 'http_path';

  /// HTTP status code attribute key
  static const String httpStatusCode = 'http_status_code';

  /// HTTP response size attribute key (in bytes)
  static const String httpResponseSize = 'http_response_size';

  // Screen attributes
  /// Screen name attribute key
  static const String screenName = 'screen_name';

  /// Screen route attribute key
  static const String screenRoute = 'screen_route';

  // Database attributes
  /// Database query name attribute key
  static const String queryName = 'query_name';

  /// Database query type attribute key (e.g., 'select', 'insert', 'update')
  static const String queryType = 'query_type';

  /// Record count attribute key
  static const String recordCount = 'record_count';

  // Computation attributes
  /// Operation name attribute key
  static const String operationName = 'operation_name';

  /// Operation type attribute key (e.g., 'usecase', 'repository')
  static const String operationType = 'operation_type';

  /// Item count attribute key
  static const String itemCount = 'item_count';

  // Error attributes
  /// Error type attribute key
  static const String errorType = 'error_type';

  /// Error message attribute key
  static const String errorMessage = 'error_message';

  // User attributes
  /// User ID attribute key
  static const String userId = 'user_id';

  /// User type attribute key
  static const String userType = 'user_type';

  // Feature attributes
  /// Feature name attribute key
  static const String featureName = 'feature_name';

  /// Feature version attribute key
  static const String featureVersion = 'feature_version';
}

/// Common performance metric names
///
/// This class provides constants for commonly used performance metric names
/// to ensure consistency across the application.
class PerformanceMetrics {
  PerformanceMetrics._();

  // Success/Error metrics
  /// Success metric name
  static const String success = 'success';

  /// Error metric name
  static const String error = 'error';

  // HTTP metrics
  /// HTTP request count metric name
  static const String httpRequestCount = 'http_request_count';

  /// HTTP response time metric name
  static const String httpResponseTime = 'http_response_time';

  // Database metrics
  /// Database query count metric name
  static const String queryCount = 'query_count';

  /// Database query time metric name
  static const String queryTime = 'query_time';

  // Screen metrics
  /// Screen load time metric name
  static const String screenLoadTime = 'screen_load_time';

  /// Screen render time metric name
  static const String screenRenderTime = 'screen_render_time';

  // Computation metrics
  /// Computation time metric name
  static const String computationTime = 'computation_time';

  /// Items processed metric name
  static const String itemsProcessed = 'items_processed';
}
