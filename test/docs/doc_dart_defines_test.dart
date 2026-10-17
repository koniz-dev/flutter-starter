// A documented `--dart-define` key must be one the app reads.
//
// The security guide once built production with
// `--dart-define=CERTIFICATE_FINGERPRINTS=...`, a key `DartDefines.values`
// does not contain, so a release built from it shipped unpinned and nothing
// failed (koniz-dev/flutter-starter#277). `tool/doc_dart_defines.dart` is the
// rule that would have caught it; `tool/check_docs.dart` runs it on every
// markdown diff, and this test runs it over the repository from the Quality
// gate (koniz-dev/flutter-starter#379).

import 'dart:io';

import 'package:flutter_starter/core/config/dart_defines.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_dart_defines.dart';

/// The production build line from docs/guides/security/implementation.md
/// before #277.
const _before = r'''
```bash
flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=CERTIFICATE_FINGERPRINTS=x
```
''';

/// The same line after #277.
const _after = r'''
```bash
flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=API_SSL_FINGERPRINTS=x
```
''';

void main() {
  final known = DartDefines.values.keys.toSet();

  group('findUnknownDartDefines', () {
    test('criterion 2: fails on CERTIFICATE_FINGERPRINTS, naming file, line '
        'and key', () {
      final problems = findUnknownDartDefines(
        _before,
        known,
        file: 'docs/guides/security/implementation.md',
      );

      expect(problems, hasLength(1));
      expect(problems.single.key, 'CERTIFICATE_FINGERPRINTS');
      expect(problems.single.line, 4);
      expect(
        problems.single.toString(),
        startsWith(
          'docs/guides/security/implementation.md:4: --dart-define key '
          '`CERTIFICATE_FINGERPRINTS`',
        ),
      );
    });

    test('criterion 2: passes on API_SSL_FINGERPRINTS', () {
      expect(findUnknownDartDefines(_after, known), isEmpty);
    });

    test('reads the space-separated form too', () {
      const source = '```bash\nflutter run --dart-define NOPE=1\n```\n';
      expect(
        findUnknownDartDefines(source, known).map((p) => p.key),
        ['NOPE'],
      );
    });

    test('checks every flag on a line', () {
      const source =
          '```bash\n'
          'flutter run --dart-define=BASE_URL=x --dart-define=NOPE=1 '
          '--dart-define=ALSO_NOPE=2\n'
          '```\n';
      expect(
        findUnknownDartDefines(source, known).map((p) => p.key),
        ['NOPE', 'ALSO_NOPE'],
      );
    });

    test('ignores --dart-define-from-file and prose outside fences', () {
      const source =
          'Pass `--dart-define=NOPE=1` in prose.\n'
          '```bash\n'
          'flutter run --dart-define-from-file=.env\n'
          '```\n';
      expect(findUnknownDartDefines(source, known), isEmpty);
    });
  });

  test('the keys parsed from source are exactly DartDefines.values', () {
    final parsed = parseDartDefineKeys(
      File(dartDefinesPath).readAsStringSync(),
    );
    expect(parsed, known);
  });

  test('criterion 3: the real README.md and docs/ name only known keys', () {
    final problems = <UnknownDartDefine>[
      for (final file in dartDefineFiles(Directory.current))
        ...findUnknownDartDefines(
          file.readAsStringSync(),
          known,
          file: file.path.substring(Directory.current.path.length + 1),
        ),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
