// Every `ENABLE_*` toggle in the configuration guide either does something or
// says that it does not.
//
// `ENABLE_DEBUG_FEATURES`, `ENABLE_ANALYTICS` and `ENABLE_CRASH_REPORTING`
// were documented and parsed by `AppConfig`, but nothing outside
// `lib/core/config/` read them, so setting one changed nothing. This test
// reads the guide's environment-variable table and, for each `ENABLE_*` row,
// looks for a reader of the matching `AppConfig` getter in `lib/`:
//
// - a row marked "Reserved" must have no reader, so it is updated when the
//   toggle is wired;
// - any other row must have at least one.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _guide = 'docs/guides/configuration.md';

/// Toggles whose only reader lives in a sample feature that
/// `tool/strip_sample_features.dart` can delete.
///
/// In a tree stripped of that feature the toggle is legitimately unread, so
/// its row is skipped there rather than failing every stripped variant.
///
/// None today: `ENABLE_DEBUG_FEATURES` is read by the route registry, which
/// every variant keeps.
const _readerFeature = <String, String>{};

/// `ENABLE_CRASH_REPORTING` -> `enableCrashReporting`.
String _getterFor(String key) {
  final words = key.toLowerCase().split('_');
  return words.first +
      words.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}

/// Source with `//` comment lines removed, so a commented-out call is not
/// counted as a reader.
String _code(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Files under `lib/` outside `lib/core/config/` that read `AppConfig.<getter>`.
List<String> _readersOf(String getter) {
  final pattern = RegExp('AppConfig\\.$getter\\b');
  return [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.g.dart') &&
          !entity.path.startsWith('lib/core/config/') &&
          pattern.hasMatch(_code(entity)))
        entity.path,
  ];
}

void main() {
  final rows = <String, String>{
    for (final line in File(_guide).readAsLinesSync())
      if (RegExp(r'^\| `(ENABLE_[A-Z_]+)` \|').firstMatch(line)
          case final match?)
        match.group(1)!: line,
  };

  test('the guide documents the ENABLE_* toggles', () {
    expect(
      rows.keys,
      containsAll(<String>[
        'ENABLE_LOGGING',
        'ENABLE_ANALYTICS',
        'ENABLE_CRASH_REPORTING',
        'ENABLE_DEBUG_FEATURES',
      ]),
    );
  });

  for (final MapEntry(:key, value: row) in rows.entries) {
    final getter = _getterFor(key);
    final reserved = row.contains('Reserved');
    final claim = reserved
        ? 'marked reserved, and nothing reads it'
        : 'has a reader of AppConfig.$getter';

    final feature = _readerFeature[key];
    final stripped = feature != null && !Directory(feature).existsSync();

    test(
      '$key: $claim',
      () {
        final readers = _readersOf(getter);
        if (reserved) {
          expect(
            readers,
            isEmpty,
            reason:
                '$key is wired now ($readers); drop "Reserved" from its row in '
                '$_guide',
          );
        } else {
          expect(
            readers,
            isNotEmpty,
            reason:
                'nothing outside lib/core/config reads AppConfig.$getter, so '
                '$key does nothing; wire it or mark its row "Reserved" in '
                '$_guide',
          );
        }
      },
      skip: stripped ? '$feature was stripped, and with it every reader' : null,
    );
  }
}
