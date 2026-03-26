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
      verify(() => mockService.startTrace('usecase_get_items')).called(1);
      verify(
        () => mockTrace.putAttribute(
          PerformanceAttributes.errorType,
          'ServerFailure',
        ),
      ).called(1);
    });

    test(
      'measureUseCaseOperation throws exception inside measureOperation',
      () async {
        when(
          () => mockService.measureOperation<Result<String>>(
            name: any(named: 'name'),
            operation: any(named: 'operation'),
            attributes: any(named: 'attributes'),
          ),
        ).thenThrow(Exception('Telemetry failed'));

        final result = await usecase.measureUseCaseOperation<String>(
          operationName: 'get_items',
          operation: () async => const Success('data'),
        );

        expect(result.isSuccess, isTrue);
        expect((result as Success).data, equals('data'));
      },
    );
  });
}
