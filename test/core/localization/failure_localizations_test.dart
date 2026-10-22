// A failure reaches the screen in the user's language, never as transport
// text.
//
// Failure.message is built by DioExceptionMapper in English, often with
// dio's own wording appended, and screens rendered it as-is. This pins the
// mapper that replaces it: every code the app produces maps to an ARB
// string, every Failure subtype has a fallback, and failure.message never
// comes back out.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wording dio appends to a connection error, verbatim.
const _dioWording =
    'The connection errored: x This indicates an error which most likely '
    'cannot be solved by the library.';

/// The failure the real mappers produce for a dio error of [type].
Failure _fromDio(DioExceptionType type) => ExceptionToFailureMapper.map(
  DioExceptionMapper.map(
    DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      message: _dioWording,
      error: const SocketException('x'),
    ),
  ),
);

/// Every `code: '...'` literal in [path], the codes that file can emit.
Set<String> _codesIn(String path) => RegExp(
  "code: '([A-Z_]+)'",
).allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!).toSet();

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final vi = lookupAppLocalizations(const Locale('vi'));

  group('criterion 1: no transport text survives', () {
    for (final type in DioExceptionType.values) {
      test('a dio $type failure', () {
        final failure = _fromDio(type);
        final shown = failure.localizedMessage(en);

        expect(failure.message, isNotEmpty);
        expect(shown, isNot(contains(failure.message)));
        expect(shown, isNot(contains('library')));
        expect(shown, isNot(contains('connection errored')));
      });
    }

    final subtypes = <Failure>[
      const ServerFailure(_dioWording),
      const NetworkFailure(_dioWording),
      const CacheFailure(_dioWording),
      const ValidationFailure(_dioWording),
      const AuthFailure(_dioWording),
      const PermissionFailure(_dioWording),
      const UnknownFailure(_dioWording),
      const NotFoundFailure(_dioWording),
    ];
    for (final failure in subtypes) {
      test('a ${failure.runtimeType} with no code falls back by type', () {
        for (final l10n in [en, vi]) {
          final shown = failure.localizedMessage(l10n);
          expect(shown, isNotEmpty);
          expect(shown, isNot(contains(failure.message)));
        }
      });
    }

    test('the subtype fallbacks are distinct, so the type still informs', () {
      final shown = subtypes.map((f) => f.localizedMessage(en)).toSet();
      expect(shown, hasLength(subtypes.length));
    });

    test('a code a backend invented is not echoed either', () {
      const failure = ServerFailure('Quota exceeded', code: 'QUOTA_EXCEEDED');

      expect(failure.localizedMessage(en), en.failureServer);
    });

    test(
      'every code DioExceptionMapper and AuthRepositoryImpl emit has its '
      'own mapping',
      () {
        // Read from the sources, so a new code added there without a mapping
        // fails here instead of silently getting the generic fallback.
        final codes = {
          ..._codesIn('lib/core/errors/dio_exception_mapper.dart'),
          ..._codesIn(
            'lib/features/auth/data/repositories/auth_repository_impl.dart',
          ),
        };
        expect(codes, contains('CONNECTION_ERROR'));
        expect(codes, contains('INVALID_AUTH_RESPONSE'));

        // UNKNOWN_ERROR means exactly what the generic fallback says.

        for (final code in codes.difference({'UNKNOWN_ERROR'})) {
          // UnknownFailure would fall back to failureUnknown; a code mapping
          // must override that.
          final shown = UnknownFailure('x', code: code).localizedMessage(en);
          expect(shown, isNot(en.failureUnknown), reason: code);
        }
      },
      skip: Platform.isLinux || Platform.isMacOS || Platform.isWindows
          ? null
          : 'reads source files',
    );
  });

  group('criterion 2: the vi string is the vi ARB value', () {
    test('CONNECTION_ERROR in vi', () {
      final arb =
          jsonDecode(File('lib/l10n/app_vi.arb').readAsStringSync())
              as Map<String, dynamic>;
      final failure = _fromDio(DioExceptionType.connectionError);

      expect(failure.code, 'CONNECTION_ERROR');
      expect(failure.localizedMessage(vi), arb['failureNoConnection']);
      expect(failure.localizedMessage(vi), isNot(en.failureNoConnection));
    });

    test('every failure key is translated in all four locales', () {
      final template =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final keys = template.keys.where((k) => k.startsWith('failure'));
      // 13 since failureInvalidCredentials.
      expect(keys, hasLength(13));

      for (final lang in ['es', 'ar', 'vi']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
                as Map<String, dynamic>;
        for (final key in keys) {
          expect(arb[key], isA<String>(), reason: '$lang $key');
          expect(arb[key], isNot(template[key]), reason: '$lang $key');
        }
      }
    });
  });
}
