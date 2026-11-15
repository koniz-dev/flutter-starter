import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Failure _fromStatus(int status) {
  final request = RequestOptions(path: '/auth/register');
  return ExceptionToFailureMapper.map(
    DioExceptionMapper.map(
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: status,
          data: {'message': 'private backend detail'},
        ),
      ),
    ),
  );
}

void main() {
  for (final language in ['en', 'es', 'vi', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(language));
    test(
      '$language preserves HTTP status and separates rejection, '
      'waiting and outage',
      () {
        for (final status in [400, 405, 409, 410, 415, 418]) {
          final failure = _fromStatus(status);
          // Preserve the transport/domain contract; only presentation changes.
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).statusCode, status);
          expect(failure.localizedMessage(l10n), l10n.failureRequestRejected);
        }
        final limited = _fromStatus(429);
        expect((limited as ServerFailure).statusCode, 429);
        expect(limited.localizedMessage(l10n), l10n.failureRateLimited);
        // Backend-supplied codes cannot override an authoritative HTTP status.
        expect(
          const ServerFailure(
            'backend',
            statusCode: 429,
            code: 'CONNECTION_ERROR',
          ).localizedMessage(l10n),
          l10n.failureRateLimited,
        );
        for (final status in [500, 502, 503]) {
          expect(
            _fromStatus(status).localizedMessage(l10n),
            l10n.failureServer,
          );
        }
        expect(
          const ServerFailure('unknown').localizedMessage(l10n),
          l10n.failureServer,
        );
      },
    );

    test('$language keeps existing typed client-error messages', () {
      expect(_fromStatus(401).localizedMessage(l10n), l10n.failureAuth);
      expect(_fromStatus(403).localizedMessage(l10n), l10n.failurePermission);
      expect(_fromStatus(404).localizedMessage(l10n), l10n.failureNotFound);
      expect(_fromStatus(422).localizedMessage(l10n), l10n.failureValidation);
    });
  }
}
