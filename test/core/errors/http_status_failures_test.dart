// HTTP error statuses must reach callers as distinguishable failures.
//
// Every bad response became a ServerException and every ServerException a
// ServerFailure with no status, so a wrong password, a 403, a 404 and a 500
// looked alike - a 404 and a 500 with the same message even compared equal -
// and AuthFailure, PermissionFailure, NotFoundFailure and ValidationFailure
// could never come from HTTP at all. These tests go through the real mappers
// the network layer uses: DioExceptionMapper, then ExceptionToFailureMapper.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_test/flutter_test.dart';

/// The failure a response with [status] becomes on its way to a repository.
Failure _failureForStatus(int status) {
  final options = RequestOptions(path: '/x');
  final dioError = DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: {'message': 'm'},
    ),
  );
  return ExceptionToFailureMapper.map(DioExceptionMapper.map(dioError));
}

/// A connection failure on its way to a repository.
Failure _failureForConnectionError() {
  final dioError = DioException.connectionError(
    requestOptions: RequestOptions(path: '/x'),
    reason: 'unreachable',
  );
  return ExceptionToFailureMapper.map(DioExceptionMapper.map(dioError));
}

void main() {
  group('criterion 1: the four statuses map to their typed failures', () {
    test('401 -> AuthFailure', () {
      expect(_failureForStatus(401), isA<AuthFailure>());
    });
    test('403 -> PermissionFailure', () {
      expect(_failureForStatus(403), isA<PermissionFailure>());
    });
    test('404 -> NotFoundFailure', () {
      expect(_failureForStatus(404), isA<NotFoundFailure>());
    });
    test('422 -> ValidationFailure', () {
      expect(_failureForStatus(422), isA<ValidationFailure>());
    });

    test('any other status stays a ServerFailure and keeps its status', () {
      final failure = _failureForStatus(500);
      expect(
        failure,
        isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 500),
      );
    });

    test('a 500 and a 503 with the same message are no longer equal', () {
      expect(_failureForStatus(500), isNot(_failureForStatus(503)));
    });

    test('copyWith keeps the status', () {
      const failure = ServerFailure('m', statusCode: 502);
      expect(
        failure.copyWith(message: 'n'),
        const ServerFailure('n', statusCode: 502),
      );
    });
  });

  test('criterion 3: every failure type docs/api/core/errors.md documents '
      'is reachable from a real producer', () {
    // How each documented type actually arises in this codebase.
    final producers = <String, Failure Function()>{
      'ServerFailure': () => _failureForStatus(500),
      'NetworkFailure': _failureForConnectionError,
      // Thrown by the tasks data source and the secure token store.
      'CacheFailure': () =>
          ExceptionToFailureMapper.map(const CacheException('disk full')),
      'AuthFailure': () => _failureForStatus(401),
      'ValidationFailure': () => _failureForStatus(422),
      'PermissionFailure': () => _failureForStatus(403),
      'NotFoundFailure': () => _failureForStatus(404),
      'UnknownFailure': () =>
          ExceptionToFailureMapper.map(const FormatException('bad json')),
    };

    final documented = {
      for (final m in RegExp(
        r'^#### `(\w+Failure)`',
        multiLine: true,
      ).allMatches(File('docs/api/core/errors.md').readAsStringSync()))
        m.group(1)!,
    };
    expect(documented, isNotEmpty);

    final unreachable = [
      for (final name in documented)
        if (!producers.containsKey(name) ||
            producers[name]!().runtimeType.toString() != name)
          name,
    ];
    expect(
      unreachable,
      isEmpty,
      reason: 'documented failure types with no real producer: $unreachable',
    );
  });
}
