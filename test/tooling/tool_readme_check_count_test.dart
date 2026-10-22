// tool/README.md must say how many checks check_docs runs.
//
// The README said "Three checks" while listing four, then "Five" while the
// tool ran seven. This counts the checks check_docs.dart actually wires in
// `main` (one `final run<Name> = ...` flag each) and requires the tool's
// header comment and the README to state that number, and the README to list
// one bullet per check.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _words = [
  'Zero',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
];

void main() {
  final tool = File('tool/check_docs.dart').readAsStringSync();
  final readme = File('tool/README.md').readAsStringSync();
  final wired = RegExp(
    r'^\s+final run[A-Z]\w* =',
    multiLine: true,
  ).allMatches(tool).length;
  final word = _words[wired];

  test('the scan sees the wired checks', () {
    expect(wired, greaterThanOrEqualTo(7));
  });

  test("criterion 3: check_docs.dart's header states the wired count", () {
    expect(tool, contains('// $word checks, all of which'));
  });

  test('criteria 1 and 3: tool/README.md states the count and lists each '
      'check', () {
    final section = readme.substring(
      readme.indexOf('## `check_docs.dart`'),
      readme.indexOf('### The `symbol:` directive'),
    );
    expect(section, contains('$word checks, all of which'));
    final bullets = RegExp(r'^- \*\*', multiLine: true).allMatches(section);
    expect(bullets, hasLength(wired));
    for (final flag in const ['--dart-defines', '--test-paths']) {
      expect(section, contains('dart run tool/check_docs.dart $flag'));
    }
  });

  test('criterion 2: the README documents the Type.member directive form', () {
    expect(readme, contains('`Type.member`'));
  });
}
