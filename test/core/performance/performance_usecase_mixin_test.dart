import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_usecase_mixin.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceService extends Mock implements IPerformanceService {}

class MockPerformanceTrace extends Mock implements IPerformanceTrace {}

class TestUseCase with PerformanceUseCaseMixin {
  TestUseCase(this.service);

  final IPerformanceService? service;

  @override
  IPerformanceService? get performanceService => service;
}

void main() {
  group('PerformanceUseCaseMixin', () {
    late MockPerformanceService mockService;
    late MockPerformanceTrace mockTrace;
    late TestUseCase usecase;

    setUp(() {
      mockService = MockPerformanceService();
      mockTrace = MockPerformanceTrace();
      usecase = TestUseCase(mockService);

      when(() => mockService.isEnabled).thenReturn(true);
    });

    test('execute operation without performance service', () async {
      final repoNoService = TestUseCase(null);
      final result = await repoNoService.measureUseCaseOperation(
        operationName: 'test',
        operation: () async => const Success('data'),
      );
      expect(result.isSuccess, isTrue);
      expect((result as Success).data, equals('data'));
    });

    test('execute operation with disabled performance service', () async {
      when(() => mockService.isEnabled).thenReturn(false);
      final result = await usecase.measureUseCaseOperation(
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

    test('measureUseCaseOperation success', () async {
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

      final result = await usecase.measureUseCaseOperation<String>(
        operationName: 'get_items',
        operation: () async => const Success('data'),
        attributes: {'custom': 'attr'},
      );

      expect(result.isSuccess, isTrue);
      verify(
        () => mockService.measureOperation<Result<String>>(
          name: 'usecase_get_items',
          operation: any(named: 'operation'),
          attributes: {
            PerformanceAttributes.operationName: 'get_items',
            PerformanceAttributes.operationType: 'usecase',
            'custom': 'attr',
          },
        ),
      ).called(1);
    });

    test('measureUseCaseOperation error', () async {
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

      final result = await usecase.measureUseCaseOperation<String>(
        operationName: 'get_items',
        operation: () async => const ResultFailure(ServerFailure('test error')),
      );

      expect(result.isFailure, isTrue);
      verify(() => mockService.startTrace('usecase_get_items_error')).called(1);
      verify(
        () => mockTrace.putAttribute(
          PerformanceAttributes.errorType,
          'ServerFailure',
        ),
      ).called(1);
      // The error trace must be started and stopped, or it is never reported.
      verify(() => mockTrace.startSync()).called(1);
      verify(() => mockTrace.stopSync()).called(1);
    });

    test('measureUseCaseOperation runs the operation exactly once', () async {
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

      var calls = 0;
      final result = await usecase.measureUseCaseOperation<String>(
        operationName: 'get_items',
        operation: () async {
          calls++;
          return const ResultFailure<String>(ServerFailure('500'));
        },
      );

      expect(result.isFailure, isTrue);
      expect(calls, 1);
    });

    test(
      'instrumentation failure propagates instead of re-running the operation',
      () async {
        when(
          () => mockService.measureOperation<Result<String>>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: any(named: 'attributes'),
          ),
        ).thenThrow(Exception('Telemetry failed'));

        var calls = 0;
        await expectLater(
          usecase.measureUseCaseOperation<String>(
            operationName: 'get_items',
            operation: () async {
              calls++;
              return const Success('data');
            },
          ),
          throwsA(isA<Exception>()),
        );

        expect(calls, 0);
      },
    );
  });
}
