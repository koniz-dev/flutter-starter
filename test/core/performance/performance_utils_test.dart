import 'package:flutter_starter/core/performance/performance_service.dart';
import 'package:flutter_starter/core/performance/performance_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceService extends Mock implements PerformanceService {}

void main() {
  group('PerformanceUtils', () {
    late MockPerformanceService mockService;

    setUp(() {
      mockService = MockPerformanceService();
    });

    group('measureApiCall', () {
      test('should call measureOperation with correct parameters', () async {
        when(() => mockService.measureOperation<String>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenAnswer((_) async => 'success');

        final result = await PerformanceUtils.measureApiCall<String>(
          service: mockService,
          method: 'GET',
          path: '/users',
          call: () async => 'success',
        );

        expect(result, 'success');
        verify(
          () => mockService.measureOperation<String>(
            name: 'api_get_/users',
            operation: any(named: 'operation'),
            attributes: {
              'http_method': 'GET',
              'http_path': '/users',
            },
          ),
        ).called(1);
      });

      test('should include additional attributes', () async {
        when(() => mockService.measureOperation<String>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenAnswer((_) async => 'success');

        await PerformanceUtils.measureApiCall<String>(
          service: mockService,
          method: 'POST',
          path: '/login',
          call: () async => 'success',
          additionalAttributes: {'user_id': '123'},
        );

        verify(
          () => mockService.measureOperation<String>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: {
              'http_method': 'POST',
              'http_path': '/login',
              'user_id': '123',
            },
          ),
        ).called(1);
      });

      test('should sanitize path with IDs', () async {
        when(() => mockService.measureOperation<String>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenAnswer((_) async => 'success');

        await PerformanceUtils.measureApiCall<String>(
          service: mockService,
          method: 'GET',
          path: '/users/123',
          call: () async => 'success',
        );

        verify(
          () => mockService.measureOperation<String>(
            name: 'api_get_/:id',
            operation: any(named: 'operation'),
            attributes: any(named: 'attributes'),
          ),
        ).called(1);
      });
    });

    group('measureDatabaseQuery', () {
      test('should call measureOperation with correct parameters', () async {
        when(() => mockService.measureOperation<List<String>>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenAnswer((_) async => ['user1', 'user2']);

        final result = await PerformanceUtils.measureDatabaseQuery<
            List<String>>(
          service: mockService,
          queryName: 'get_users',
          query: () async => ['user1', 'user2'],
        );

        expect(result, ['user1', 'user2']);
        verify(
          () => mockService.measureOperation<List<String>>(
            name: 'db_query_get_users',
            operation: any(named: 'operation'),
            attributes: {
              'query_name': 'get_users',
            },
          ),
        ).called(1);
      });

      test('should include additional attributes', () async {
        when(() => mockService.measureOperation<List<String>>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenAnswer((_) async => []);

        await PerformanceUtils.measureDatabaseQuery<List<String>>(
          service: mockService,
          queryName: 'get_users',
          query: () async => [],
          attributes: {'table': 'users'},
        );

        verify(
          () => mockService.measureOperation<List<String>>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: {
              'query_name': 'get_users',
              'table': 'users',
            },
          ),
        ).called(1);
      });
    });

    group('measureComputation', () {
      test('should call measureOperation with correct parameters', () async {
        when(() => mockService.measureOperation<int>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenAnswer((_) async => 42);

        final result = await PerformanceUtils.measureComputation<int>(
          service: mockService,
          operationName: 'image_processing',
          computation: () async => 42,
        );

        expect(result, 42);
        verify(
          () => mockService.measureOperation<int>(
            name: 'computation_image_processing',
            operation: any(named: 'operation'),
          ),
        ).called(1);
      });

      test('should include attributes', () async {
        when(() => mockService.measureOperation<int>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenAnswer((_) async => 42);

        await PerformanceUtils.measureComputation<int>(
          service: mockService,
          operationName: 'image_processing',
          computation: () async => 42,
          attributes: {'format': 'jpeg'},
        );

        verify(
          () => mockService.measureOperation<int>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: {'format': 'jpeg'},
          ),
        ).called(1);
      });
    });

    group('measureSyncComputation', () {
      test('should call measureSyncOperation with correct parameters', () {
        when(() => mockService.measureSyncOperation<int>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenReturn(42);

        final result = PerformanceUtils.measureSyncComputation<int>(
          service: mockService,
          operationName: 'data_parsing',
          computation: () => 42,
        );

        expect(result, 42);
        verify(
          () => mockService.measureSyncOperation<int>(
            name: 'computation_data_parsing',
            operation: any(named: 'operation'),
          ),
        ).called(1);
      });

      test('should include attributes', () {
        when(() => mockService.measureSyncOperation<String>(
              name: any(named: 'name'),
              operation: any(named: 'operation'),
              attributes: any(named: 'attributes'),
            ),).thenReturn('parsed');

        final result = PerformanceUtils.measureSyncComputation<String>(
          service: mockService,
          operationName: 'data_parsing',
          computation: () => 'parsed',
          attributes: {'format': 'json'},
        );

        expect(result, 'parsed');
        verify(
          () => mockService.measureSyncOperation<String>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: {'format': 'json'},
          ),
        ).called(1);
      });
    });
  });

  group('PerformanceServiceExtension', () {
    late MockPerformanceService mockService;

    setUp(() {
      mockService = MockPerformanceService();
    });

    test('measureApiCall should delegate to PerformanceUtils', () async {
      when(() => mockService.measureOperation<String>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: any(named: 'attributes'),
          ),).thenAnswer((_) async => 'success');

      final result = await mockService.measureApiCall<String>(
        method: 'GET',
        path: '/users',
        call: () async => 'success',
      );

      expect(result, 'success');
      verify(
        () => mockService.measureOperation<String>(
          name: 'api_get_/users',
          operation: any(named: 'operation'),
          attributes: {
            'http_method': 'GET',
            'http_path': '/users',
          },
        ),
      ).called(1);
    });

    test('measureDatabaseQuery should delegate to PerformanceUtils', () async {
      when(() => mockService.measureOperation<List<String>>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: any(named: 'attributes'),
          ),).thenAnswer((_) async => []);

      final result = await mockService.measureDatabaseQuery<List<String>>(
        queryName: 'get_users',
        query: () async => [],
      );

      expect(result, isEmpty);
      verify(
        () => mockService.measureOperation<List<String>>(
          name: 'db_query_get_users',
          operation: any(named: 'operation'),
          attributes: {
            'query_name': 'get_users',
          },
        ),
      ).called(1);
    });

    test('measureComputation should delegate to PerformanceUtils', () async {
      when(() => mockService.measureOperation<int>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: any(named: 'attributes'),
          ),).thenAnswer((_) async => 42);

      final result = await mockService.measureComputation<int>(
        operationName: 'test',
        computation: () async => 42,
      );

      expect(result, 42);
        verify(
          () => mockService.measureOperation<int>(
            name: 'computation_test',
            operation: any(named: 'operation'),
          ),
        ).called(1);
    });
  });
}
