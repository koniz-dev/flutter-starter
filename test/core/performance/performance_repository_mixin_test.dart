import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_repository_mixin.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceService extends Mock implements IPerformanceService {}

class MockPerformanceTrace extends Mock implements IPerformanceTrace {}

class TestRepository with PerformanceRepositoryMixin {
  TestRepository(this.service);

  final IPerformanceService? service;

  @override
  IPerformanceService? get performanceService => service;
}

void main() {
  group('PerformanceRepositoryMixin', () {
    late MockPerformanceService mockService;
    late MockPerformanceTrace mockTrace;
    late TestRepository repository;

    setUp(() {
      mockService = MockPerformanceService();
      mockTrace = MockPerformanceTrace();
      repository = TestRepository(mockService);

      when(() => mockService.isEnabled).thenReturn(true);
    });

    test('execute operation without performance service', () async {
      final repoNoService = TestRepository(null);
      final result = await repoNoService.measureRepositoryOperation(
        operationName: 'test',
        operation: () async => const Success('data'),
      );
      expect(result.isSuccess, isTrue);
      expect((result as Success).data, equals('data'));
    });

    test('execute operation with disabled performance service', () async {
      when(() => mockService.isEnabled).thenReturn(false);
      final result = await repository.measureRepositoryOperation(
        operationName: 'test',
        operation: () async => const Success('data'),
      );
      expect(result.isSuccess, isTrue);
      verifyNever(
        () => mockService.measureOperation(
          name: any(named: 'name'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test('measureRepositoryOperation success', () async {
      // Mock measureOperation to execute the callback
      when(
        () => mockService.measureOperation<Result<String>>(
          name: any(named: 'name'),
          operation: any(named: 'operation'),
          attributes: any(named: 'attributes'),
        ),
      ).thenAnswer((invocation) async {
        final cb =
            invocation.namedArguments[#operation]
                as Future<Result<String>> Function();
        return cb();
      });

      final result = await repository.measureRepositoryOperation<String>(
        operationName: 'get_items',
        operation: () async => const Success('data'),
        attributes: {'custom': 'attr'},
      );

      expect(result.isSuccess, isTrue);
      verify(
        () => mockService.measureOperation<Result<String>>(
          name: 'repository_get_items',
          operation: any(named: 'operation'),
          attributes: {
            PerformanceAttributes.operationName: 'get_items',
            'custom': 'attr',
          },
        ),
      ).called(1);
    });

    test('measureRepositoryOperation error', () async {
      when(
        () => mockService.measureOperation<Result<String>>(
          name: any(named: 'name'),
          operation: any(named: 'operation'),
          attributes: any(named: 'attributes'),
        ),
      ).thenAnswer((invocation) async {
        final cb =
            invocation.namedArguments[#operation]
                as Future<Result<String>> Function();
        return cb();
      });
      when(() => mockService.startTrace(any())).thenReturn(mockTrace);

      final result = await repository.measureRepositoryOperation<String>(
        operationName: 'get_items',
        operation: () async => const ResultFailure(ServerFailure('test error')),
      );

      expect(result.isFailure, isTrue);
      verify(() => mockService.startTrace('repository_get_items')).called(1);
      verify(
        () => mockTrace.putAttribute(
          PerformanceAttributes.errorType,
          'ServerFailure',
        ),
      ).called(1);
    });

    test(
      'measureRepositoryOperation throws exception inside measureOperation',
      () async {
        when(
          () => mockService.measureOperation<Result<String>>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: any(named: 'attributes'),
          ),
        ).thenThrow(Exception('Telemetry failed'));

        final result = await repository.measureRepositoryOperation<String>(
          operationName: 'get_items',
          operation: () async => const Success('data'),
        );

        expect(result.isSuccess, isTrue);
        expect((result as Success).data, equals('data'));
      },
    );

    test('measureDataFetch', () async {
      when(
        () => mockService.measureOperation<Result<String>>(
          name: any(named: 'name'),
          operation: any(named: 'operation'),
          attributes: any(named: 'attributes'),
        ),
      ).thenAnswer((invocation) async {
        final cb =
            invocation.namedArguments[#operation]
                as Future<Result<String>> Function();
        return cb();
      });

      await repository.measureDataFetch<String>(
        operationName: 'fetch_items',
        recordCount: 5,
        operation: () async => const Success('data'),
      );

      verify(
        () => mockService.measureOperation<Result<String>>(
          name: 'repository_fetch_items',
          operation: any(named: 'operation'),
          attributes: {
            PerformanceAttributes.operationName: 'fetch_items',
            PerformanceAttributes.queryType: 'fetch',
            PerformanceAttributes.recordCount: '5',
          },
        ),
      ).called(1);
    });

    test('measureDataSave', () async {
      when(
        () => mockService.measureOperation<Result<String>>(
          name: any(named: 'name'),
          operation: any(named: 'operation'),
          attributes: any(named: 'attributes'),
        ),
      ).thenAnswer((invocation) async {
        final cb =
            invocation.namedArguments[#operation]
                as Future<Result<String>> Function();
        return cb();
      });

      await repository.measureDataSave<String>(
        operationName: 'save_items',
        operation: () async => const Success('data'),
      );

      verify(
        () => mockService.measureOperation<Result<String>>(
          name: 'repository_save_items',
          operation: any(named: 'operation'),
          attributes: {
            PerformanceAttributes.operationName: 'save_items',
            PerformanceAttributes.queryType: 'save',
          },
        ),
      ).called(1);
    });
  });
}
