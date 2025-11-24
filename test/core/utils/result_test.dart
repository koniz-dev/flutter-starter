import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('should create Success with data', () {
        const result = Success<String>('test');
        expect(result.data, 'test');
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('should handle nullable data', () {
        const result = Success<String?>(null);
        expect(result.data, isNull);
        expect(result.isSuccess, isTrue);
      });

      test('should return data from dataOrNull', () {
        const result = Success<String>('test');
        expect(result.dataOrNull, 'test');
      });

      test('should return null from errorOrNull', () {
        const result = Success<String>('test');
        expect(result.errorOrNull, isNull);
      });

      test('should return null from failureOrNull', () {
        const result = Success<String>('test');
        expect(result.failureOrNull, isNull);
      });
    });

    group('ResultFailure', () {
      test('should create ResultFailure with Failure', () {
        const failure = ServerFailure('Server error', code: '500');
        const result = ResultFailure<String>(failure);

        expect(result.failure, failure);
        expect(result.message, 'Server error');
        expect(result.code, '500');
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
      });

      test('should return null from dataOrNull', () {
        const failure = ServerFailure('Server error');
        const result = ResultFailure<String>(failure);
        expect(result.dataOrNull, isNull);
      });

      test('should return message from errorOrNull', () {
        const failure = ServerFailure('Server error');
        const result = ResultFailure<String>(failure);
        expect(result.errorOrNull, 'Server error');
      });

      test('should return failure from failureOrNull', () {
        const failure = ServerFailure('Server error');
        const result = ResultFailure<String>(failure);
        expect(result.failureOrNull, failure);
      });

      test('should handle different Failure subtypes', () {
        const networkFailure = NetworkFailure('Network error');
        const authFailure = AuthFailure('Auth error', code: '401');
        const validationFailure = ValidationFailure('Validation error');

        const networkResult = ResultFailure<String>(networkFailure);
        const authResult = ResultFailure<String>(authFailure);
        const validationResult = ResultFailure<String>(validationFailure);

        expect(networkResult.failure, isA<NetworkFailure>());
        expect(authResult.failure, isA<AuthFailure>());
        expect(validationResult.failure, isA<ValidationFailure>());
      });
    });

    group('when() - Pattern Matching', () {
      test('should call success callback for Success', () {
        const result = Success<String>('test');
        String? capturedData;

        result.when(
          success: (data) {
            capturedData = data;
          },
          failureCallback: (failure) {
            fail('Should not call failure callback');
          },
        );

        expect(capturedData, 'test');
      });

      test('should call failureCallback for ResultFailure', () {
        const failure = ServerFailure('Server error', code: '500');
        const result = ResultFailure<String>(failure);
        Failure? capturedFailure;

        result.when(
          success: (data) {
            fail('Should not call success callback');
          },
          failureCallback: (f) {
            capturedFailure = f;
          },
        );

        expect(capturedFailure, failure);
        expect(capturedFailure, isA<ServerFailure>());
      });

      test('should return value from success callback', () {
        const result = Success<int>(42);
        final value = result.when(
          success: (data) => data * 2,
          failureCallback: (failure) => 0,
        );

        expect(value, 84);
      });

      test('should return value from failureCallback', () {
        const failure = NetworkFailure('Network error');
        const result = ResultFailure<int>(failure);
        final value = result.when(
          success: (data) => data * 2,
          failureCallback: (failure) => -1,
        );

        expect(value, -1);
      });

      test('should handle async callbacks', () async {
        const result = Success<String>('test');
        final value = await result.when(
          success: (data) async => 'Success: $data',
          failureCallback: (failure) async => 'Failure',
        );

        expect(value, 'Success: test');
      });

      test('should preserve type information in success callback', () {
        const result = Success<List<String>>(['a', 'b', 'c']);
        // when() returns a value, so cascade operator is not appropriate here
        // ignore: cascade_invocations
        result.when(
          success: (data) {
            // Type should be List<String>
            expect(data, isA<List<String>>());
            expect(data.length, 3);
            expect(data.first, 'a');
          },
          failureCallback: (failure) {
            fail('Should not call failure callback');
          },
        );
      });

      test('should preserve Failure subtype information', () {
        const authFailure = AuthFailure('Auth error', code: '401');
        const result = ResultFailure<String>(authFailure);

        // when() returns a value, so cascade operator is not appropriate here
        // ignore: cascade_invocations
        result.when(
          success: (data) {
            fail('Should not call success callback');
          },
          failureCallback: (failure) {
            // Can pattern match on Failure subtypes
            if (failure is AuthFailure) {
              expect(failure.code, '401');
            } else {
              fail('Failure should be AuthFailure');
            }
          },
        );
      });

      test('should handle all Failure subtypes', () {
        const failures = [
          ServerFailure('Server error'),
          NetworkFailure('Network error'),
          CacheFailure('Cache error'),
          AuthFailure('Auth error'),
          ValidationFailure('Validation error'),
          PermissionFailure('Permission error'),
          UnknownFailure('Unknown error'),
        ];

        for (final failure in failures) {
          final result = ResultFailure<String>(failure);
          // when() returns a value, so cascade operator is not appropriate here
          // ignore: cascade_invocations
          result.when(
            success: (data) {
              fail('Should not call success callback');
            },
            failureCallback: (f) {
              expect(f.message, failure.message);
              expect(f, isA<Failure>());
            },
          );
        }
      });

      test('should handle nullable T types', () {
        const result = Success<String?>(null);
        // when() returns a value, so cascade operator is not appropriate here
        // ignore: cascade_invocations
        result.when(
          success: (data) {
            expect(data, isNull);
          },
          failureCallback: (failure) {
            fail('Should not call failure callback');
          },
        );
      });
    });

    group('map()', () {
      test('should map Success data', () {
        const result = Success<int>(42);
        final mapped = result.map((data) => data.toString());

        expect(mapped, isA<Success<String>>());
        expect((mapped as Success<String>).data, '42');
      });

      test('should preserve Failure in map', () {
        const failure = ServerFailure('Server error');
        const result = ResultFailure<int>(failure);
        final mapped = result.map((data) => data.toString());

        expect(mapped, isA<ResultFailure<String>>());
        expect((mapped as ResultFailure<String>).failure, failure);
      });
    });

    group('mapError()', () {
      test('should not change Success', () {
        const result = Success<String>('test');
        final mapped = result.mapError((message) => 'Mapped: $message');

        expect(mapped, result);
      });

      test('should map Failure message', () {
        const failure = ServerFailure('Original error');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        expect(mapped, isA<ResultFailure<String>>());
        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Original error');
        expect(mappedFailure, isA<ServerFailure>());
      });
    });

    group('when() - Pattern Matching', () {
      test('should call success callback for Success', () {
        const result = Success<String>('test');
        String? capturedData;

        result.when(
          success: (data) {
            capturedData = data;
          },
          failureCallback: (failure) {
            fail('Should not call failure callback');
          },
        );

        expect(capturedData, 'test');
      });

      test('should call failureCallback with message and code', () {
        const failure = ServerFailure('Server error', code: '500');
        const result = ResultFailure<String>(failure);
        String? capturedMessage;
        String? capturedCode;

        result.when(
          success: (data) {
            fail('Should not call success callback');
          },
          failureCallback: (f) {
            capturedMessage = f.message;
            capturedCode = f.code;
          },
        );

        expect(capturedMessage, 'Server error');
        expect(capturedCode, '500');
      });

      test('should handle null code in failureCallback', () {
        const failure = NetworkFailure('Network error');
        const result = ResultFailure<String>(failure);
        String? capturedCode;

        result.when(
          success: (data) {
            fail('Should not call success callback');
          },
          failureCallback: (f) {
            capturedCode = f.code;
          },
        );

        expect(capturedCode, isNull);
      });
    });

    group('mapError() - Comprehensive Failure Type Coverage', () {
      test('should map ServerFailure message', () {
        const failure = ServerFailure('Original error', code: '500');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        expect(mapped, isA<ResultFailure<String>>());
        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Original error');
        expect(mappedFailure, isA<ServerFailure>());
        expect(mappedFailure.code, '500');
      });

      test('should map NetworkFailure message', () {
        const failure = NetworkFailure('Network error', code: 'NET_ERR');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Network error');
        expect(mappedFailure, isA<NetworkFailure>());
        expect(mappedFailure.code, 'NET_ERR');
      });

      test('should map CacheFailure message', () {
        const failure = CacheFailure('Cache error', code: 'CACHE_ERR');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Cache error');
        expect(mappedFailure, isA<CacheFailure>());
        expect(mappedFailure.code, 'CACHE_ERR');
      });

      test('should map AuthFailure message', () {
        const failure = AuthFailure('Auth error', code: '401');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Auth error');
        expect(mappedFailure, isA<AuthFailure>());
        expect(mappedFailure.code, '401');
      });

      test('should map ValidationFailure message', () {
        const failure = ValidationFailure('Validation error', code: 'VALID');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Validation error');
        expect(mappedFailure, isA<ValidationFailure>());
        expect(mappedFailure.code, 'VALID');
      });

      test('should map PermissionFailure message', () {
        const failure = PermissionFailure('Permission error', code: 'PERM');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Permission error');
        expect(mappedFailure, isA<PermissionFailure>());
        expect(mappedFailure.code, 'PERM');
      });

      test('should map UnknownFailure message', () {
        const failure = UnknownFailure('Unknown error', code: 'UNKNOWN');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Unknown error');
        expect(mappedFailure, isA<UnknownFailure>());
        expect(mappedFailure.code, 'UNKNOWN');
      });
    });

    group('Integration with when()', () {
      test('should chain map and when', () {
        const result = Success<int>(42);
        final value = result.map((data) => data * 2).when(
              success: (data) => 'Result: $data',
              failureCallback: (failure) => 'Error',
            );

        expect(value, 'Result: 84');
      });

      test('should handle complex type transformations', () {
        const result = Success<List<int>>([1, 2, 3]);
        final value =
            result.map((data) => data.map((e) => e * 2).toList()).when(
                  success: (data) => data.join(', '),
                  failureCallback: (failure) => 'Error',
                );

        expect(value, '2, 4, 6');
      });

      test('should chain mapError and when', () {
        const failure = ServerFailure('Original error');
        const result = ResultFailure<String>(failure);
        final value = result.mapError((message) => 'Mapped: $message').when(
              success: (data) => 'Success',
              failureCallback: (f) => f.message,
            );

        expect(value, 'Mapped: Original error');
      });
    });

    group('Edge Cases - Additional Coverage', () {
      test('should handle mapError with empty message', () {
        const failure = ServerFailure('');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'New: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'New: ');
      });

      test('should handle mapError with null code', () {
        const failure = ServerFailure('Error');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.code, isNull);
      });

      test('should preserve code when mapping error', () {
        const failure = ServerFailure('Error', code: 'CODE123');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'New: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.code, 'CODE123');
      });

      test('should handle map on ResultFailure', () {
        const failure = ServerFailure('Error');
        const result = ResultFailure<int>(failure);
        final mapped = result.map((data) => data * 2);

        expect(mapped, isA<ResultFailure<int>>());
        expect((mapped as ResultFailure<int>).failure, failure);
      });

      test('should handle mapError on Success', () {
        const result = Success<String>('data');
        final mapped = result.mapError((message) => 'Mapped: $message');

        expect(mapped, isA<Success<String>>());
        expect((mapped as Success<String>).data, 'data');
      });
    });

    group('whenLegacy() - Deprecated Pattern Matching', () {
      test('should call success callback for Success', () {
        const result = Success<String>('test');
        String? capturedData;

        result.whenLegacy(
          success: (data) {
            capturedData = data;
          },
          failureCallback: (message, code) {
            fail('Should not call failure callback');
          },
        );

        expect(capturedData, 'test');
      });

      test('should call failureCallback with message and code for ResultFailure',
          () {
        const failure = ServerFailure('Server error', code: '500');
        const result = ResultFailure<String>(failure);
        String? capturedMessage;
        String? capturedCode;

        result.whenLegacy(
          success: (data) {
            fail('Should not call success callback');
          },
          failureCallback: (message, code) {
            capturedMessage = message;
            capturedCode = code;
          },
        );

        expect(capturedMessage, 'Server error');
        expect(capturedCode, '500');
      });

      test('should handle null code in failureCallback', () {
        const failure = NetworkFailure('Network error');
        const result = ResultFailure<String>(failure);
        String? capturedCode;

        result.whenLegacy(
          success: (data) {
            fail('Should not call success callback');
          },
          failureCallback: (message, code) {
            capturedCode = code;
          },
        );

        expect(capturedCode, isNull);
      });

      test('should return value from success callback', () {
        const result = Success<int>(42);
        final value = result.whenLegacy(
          success: (data) => data * 2,
          failureCallback: (message, code) => 0,
        );

        expect(value, 84);
      });

      test('should return value from failureCallback', () {
        const failure = NetworkFailure('Network error');
        const result = ResultFailure<int>(failure);
        final value = result.whenLegacy(
          success: (data) => data * 2,
          failureCallback: (message, code) => -1,
        );

        expect(value, -1);
      });
    });

    group('mapError() - NotFoundFailure Coverage', () {
      test('should map NotFoundFailure message', () {
        const failure = NotFoundFailure('Not found', code: '404');
        const result = ResultFailure<String>(failure);
        final mapped = result.mapError((message) => 'Mapped: $message');

        final mappedFailure = (mapped as ResultFailure<String>).failure;
        expect(mappedFailure.message, 'Mapped: Not found');
        expect(mappedFailure, isA<NotFoundFailure>());
        expect(mappedFailure.code, '404');
      });
    });
  });
}
