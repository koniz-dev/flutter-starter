// docs/api/core/utils.md listed only DateFormatter's display pair, not the
// lossless ISO-8601 pair meant for stored data, and left three validators
// out. Every public static method of these classes is now listed there.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The public static methods declared in [path].
List<String> _publicStatics(String path) => [
  for (final m in RegExp(
    r'^  static [\w<>?, ]+ ([a-z]\w*)\(',
    multiLine: true,
  ).allMatches(File(path).readAsStringSync()))
    m.group(1)!,
];

void main() {
  final doc = File('docs/api/core/utils.md').readAsStringSync();

  for (final (type, path) in [
    ('DateFormatter', 'lib/core/utils/date_formatter.dart'),
    ('Validators', 'lib/core/utils/validators.dart'),
  ]) {
    test('utils.md lists every public static of $type', () {
      final statics = _publicStatics(path);
      expect(statics, isNotEmpty);
      final section = doc.substring(doc.indexOf('## $type'));
      for (final name in statics) {
        expect(section, contains(' $name('), reason: '$type.$name');
      }
    });
  }

  test('utils.md gives the UTC caveat for the display pair', () {
    expect(doc, contains('lossy for a UTC `DateTime`'));
  });
}
