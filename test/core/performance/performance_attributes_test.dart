import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerformanceAttributes', () {
    test('should have all HTTP attribute constants', () {
      expect(PerformanceAttributes.httpMethod, isA<String>());
      expect(PerformanceAttributes.httpMethod, isNotEmpty);
      expect(PerformanceAttributes.httpMethod, 'http_method');

      expect(PerformanceAttributes.httpPath, isA<String>());
      expect(PerformanceAttributes.httpPath, isNotEmpty);
      expect(PerformanceAttributes.httpPath, 'http_path');

      expect(PerformanceAttributes.httpStatusCode, isA<String>());
      expect(PerformanceAttributes.httpStatusCode, isNotEmpty);
      expect(PerformanceAttributes.httpStatusCode, 'http_status_code');

      expect(PerformanceAttributes.httpResponseSize, isA<String>());
      expect(PerformanceAttributes.httpResponseSize, isNotEmpty);
      expect(PerformanceAttributes.httpResponseSize, 'http_response_size');
    });

    test('should have all screen attribute constants', () {
      expect(PerformanceAttributes.screenName, isA<String>());
      expect(PerformanceAttributes.screenName, isNotEmpty);
      expect(PerformanceAttributes.screenName, 'screen_name');

      expect(PerformanceAttributes.screenRoute, isA<String>());
      expect(PerformanceAttributes.screenRoute, isNotEmpty);
      expect(PerformanceAttributes.screenRoute, 'screen_route');
    });

    test('should have all database attribute constants', () {
      expect(PerformanceAttributes.queryName, isA<String>());
      expect(PerformanceAttributes.queryName, isNotEmpty);
      expect(PerformanceAttributes.queryName, 'query_name');

      expect(PerformanceAttributes.queryType, isA<String>());
      expect(PerformanceAttributes.queryType, isNotEmpty);
      expect(PerformanceAttributes.queryType, 'query_type');

      expect(PerformanceAttributes.recordCount, isA<String>());
      expect(PerformanceAttributes.recordCount, isNotEmpty);
      expect(PerformanceAttributes.recordCount, 'record_count');
    });

    test('should have all computation attribute constants', () {
      expect(PerformanceAttributes.operationName, isA<String>());
      expect(PerformanceAttributes.operationName, isNotEmpty);
      expect(PerformanceAttributes.operationName, 'operation_name');

      expect(PerformanceAttributes.operationType, isA<String>());
      expect(PerformanceAttributes.operationType, isNotEmpty);
      expect(PerformanceAttributes.operationType, 'operation_type');

      expect(PerformanceAttributes.itemCount, isA<String>());
      expect(PerformanceAttributes.itemCount, isNotEmpty);
      expect(PerformanceAttributes.itemCount, 'item_count');
    });

    test('should have all error attribute constants', () {
      expect(PerformanceAttributes.errorType, isA<String>());
      expect(PerformanceAttributes.errorType, isNotEmpty);
      expect(PerformanceAttributes.errorType, 'error_type');

      expect(PerformanceAttributes.errorMessage, isA<String>());
      expect(PerformanceAttributes.errorMessage, isNotEmpty);
      expect(PerformanceAttributes.errorMessage, 'error_message');
    });

    test('should have all user attribute constants', () {
      expect(PerformanceAttributes.userId, isA<String>());
      expect(PerformanceAttributes.userId, isNotEmpty);
      expect(PerformanceAttributes.userId, 'user_id');

      expect(PerformanceAttributes.userType, isA<String>());
      expect(PerformanceAttributes.userType, isNotEmpty);
      expect(PerformanceAttributes.userType, 'user_type');
    });

    test('should have all feature attribute constants', () {
      expect(PerformanceAttributes.featureName, isA<String>());
      expect(PerformanceAttributes.featureName, isNotEmpty);
      expect(PerformanceAttributes.featureName, 'feature_name');

      expect(PerformanceAttributes.featureVersion, isA<String>());
      expect(PerformanceAttributes.featureVersion, isNotEmpty);
      expect(PerformanceAttributes.featureVersion, 'feature_version');
    });

    test('should have all unique attribute constants', () {
      final attributes = [
        PerformanceAttributes.httpMethod,
        PerformanceAttributes.httpPath,
        PerformanceAttributes.httpStatusCode,
        PerformanceAttributes.httpResponseSize,
        PerformanceAttributes.screenName,
        PerformanceAttributes.screenRoute,
        PerformanceAttributes.queryName,
        PerformanceAttributes.queryType,
        PerformanceAttributes.recordCount,
        PerformanceAttributes.operationName,
        PerformanceAttributes.operationType,
        PerformanceAttributes.itemCount,
        PerformanceAttributes.errorType,
        PerformanceAttributes.errorMessage,
        PerformanceAttributes.userId,
        PerformanceAttributes.userType,
        PerformanceAttributes.featureName,
        PerformanceAttributes.featureVersion,
      ];

      // All attributes should be unique
      expect(attributes.toSet().length, attributes.length);
    });

    test('should have all non-empty attribute constants', () {
      expect(PerformanceAttributes.httpMethod.length, greaterThan(0));
      expect(PerformanceAttributes.httpPath.length, greaterThan(0));
      expect(PerformanceAttributes.httpStatusCode.length, greaterThan(0));
      expect(PerformanceAttributes.httpResponseSize.length, greaterThan(0));
      expect(PerformanceAttributes.screenName.length, greaterThan(0));
      expect(PerformanceAttributes.screenRoute.length, greaterThan(0));
      expect(PerformanceAttributes.queryName.length, greaterThan(0));
      expect(PerformanceAttributes.queryType.length, greaterThan(0));
      expect(PerformanceAttributes.recordCount.length, greaterThan(0));
      expect(PerformanceAttributes.operationName.length, greaterThan(0));
      expect(PerformanceAttributes.operationType.length, greaterThan(0));
      expect(PerformanceAttributes.itemCount.length, greaterThan(0));
      expect(PerformanceAttributes.errorType.length, greaterThan(0));
      expect(PerformanceAttributes.errorMessage.length, greaterThan(0));
      expect(PerformanceAttributes.userId.length, greaterThan(0));
      expect(PerformanceAttributes.userType.length, greaterThan(0));
      expect(PerformanceAttributes.featureName.length, greaterThan(0));
      expect(PerformanceAttributes.featureVersion.length, greaterThan(0));
    });
  });

  group('PerformanceMetrics', () {
    test('should have all success/error metric constants', () {
      expect(PerformanceMetrics.success, isA<String>());
      expect(PerformanceMetrics.success, isNotEmpty);
      expect(PerformanceMetrics.success, 'success');

      expect(PerformanceMetrics.error, isA<String>());
      expect(PerformanceMetrics.error, isNotEmpty);
      expect(PerformanceMetrics.error, 'error');
    });

    test('should have all HTTP metric constants', () {
      expect(PerformanceMetrics.httpRequestCount, isA<String>());
      expect(PerformanceMetrics.httpRequestCount, isNotEmpty);
      expect(PerformanceMetrics.httpRequestCount, 'http_request_count');

      expect(PerformanceMetrics.httpResponseTime, isA<String>());
      expect(PerformanceMetrics.httpResponseTime, isNotEmpty);
      expect(PerformanceMetrics.httpResponseTime, 'http_response_time');
    });

    test('should have all database metric constants', () {
      expect(PerformanceMetrics.queryCount, isA<String>());
      expect(PerformanceMetrics.queryCount, isNotEmpty);
      expect(PerformanceMetrics.queryCount, 'query_count');

      expect(PerformanceMetrics.queryTime, isA<String>());
      expect(PerformanceMetrics.queryTime, isNotEmpty);
      expect(PerformanceMetrics.queryTime, 'query_time');
    });

    test('should have all screen metric constants', () {
      expect(PerformanceMetrics.screenLoadTime, isA<String>());
      expect(PerformanceMetrics.screenLoadTime, isNotEmpty);
      expect(PerformanceMetrics.screenLoadTime, 'screen_load_time');

      expect(PerformanceMetrics.screenRenderTime, isA<String>());
      expect(PerformanceMetrics.screenRenderTime, isNotEmpty);
      expect(PerformanceMetrics.screenRenderTime, 'screen_render_time');
    });

    test('should have all computation metric constants', () {
      expect(PerformanceMetrics.computationTime, isA<String>());
      expect(PerformanceMetrics.computationTime, isNotEmpty);
      expect(PerformanceMetrics.computationTime, 'computation_time');

      expect(PerformanceMetrics.itemsProcessed, isA<String>());
      expect(PerformanceMetrics.itemsProcessed, isNotEmpty);
      expect(PerformanceMetrics.itemsProcessed, 'items_processed');
    });

    test('should have all unique metric constants', () {
      final metrics = [
        PerformanceMetrics.success,
        PerformanceMetrics.error,
        PerformanceMetrics.httpRequestCount,
        PerformanceMetrics.httpResponseTime,
        PerformanceMetrics.queryCount,
        PerformanceMetrics.queryTime,
        PerformanceMetrics.screenLoadTime,
        PerformanceMetrics.screenRenderTime,
        PerformanceMetrics.computationTime,
        PerformanceMetrics.itemsProcessed,
      ];

      // All metrics should be unique
      expect(metrics.toSet().length, metrics.length);
    });

    test('should have all non-empty metric constants', () {
      expect(PerformanceMetrics.success.length, greaterThan(0));
      expect(PerformanceMetrics.error.length, greaterThan(0));
      expect(PerformanceMetrics.httpRequestCount.length, greaterThan(0));
      expect(PerformanceMetrics.httpResponseTime.length, greaterThan(0));
      expect(PerformanceMetrics.queryCount.length, greaterThan(0));
      expect(PerformanceMetrics.queryTime.length, greaterThan(0));
      expect(PerformanceMetrics.screenLoadTime.length, greaterThan(0));
      expect(PerformanceMetrics.screenRenderTime.length, greaterThan(0));
      expect(PerformanceMetrics.computationTime.length, greaterThan(0));
      expect(PerformanceMetrics.itemsProcessed.length, greaterThan(0));
    });

    test('should have consistent naming convention', () {
      // All metrics should use snake_case
      final metrics = [
        PerformanceMetrics.success,
        PerformanceMetrics.error,
        PerformanceMetrics.httpRequestCount,
        PerformanceMetrics.httpResponseTime,
        PerformanceMetrics.queryCount,
        PerformanceMetrics.queryTime,
        PerformanceMetrics.screenLoadTime,
        PerformanceMetrics.screenRenderTime,
        PerformanceMetrics.computationTime,
        PerformanceMetrics.itemsProcessed,
      ];

      for (final metric in metrics) {
        // Should not contain spaces or uppercase (except first letter)
        expect(metric, isNot(contains(' ')));
        // Should use underscores for word separation
        if (metric.contains(RegExp('[A-Z]'))) {
          // If contains uppercase, should be camelCase converted to snake_case
          expect(metric, matches(RegExp(r'^[a-z]+(_[a-z]+)*$')));
        }
      }
    });
  });
}
