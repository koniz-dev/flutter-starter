// The declaration scanner in tool/doc_symbols.dart skips string literals. It
// read a backslash as an escape in every literal, so a raw string ending in
// one - `r'\'`, valid Dart and what use_raw_strings asks for - never closed,
// and every declaration after it in the class looked missing.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_symbols.dart';

void main() {
  for (final literal in [r"r'\'", r'r"\"', r"r'''\'''", r"r'a\'"]) {
    test('a declaration after $literal is found', () {
      final source =
          '''
class Sample {
  static const backslash = $literal;

  static String later() => '';
}
''';

      expect(declaresMember(source, 'Sample', 'later'), isTrue);
    });
  }

  test('an escaped quote in an ordinary string still does not close it', () {
    const source = r'''
class Sample {
  static const quote = 'it\'s';

  static String later() => '';
}
''';

    expect(declaresMember(source, 'Sample', 'later'), isTrue);
  });
}
