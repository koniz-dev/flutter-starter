// Every test body must assert something (koniz-dev/flutter-starter#377).
//
// 'should handle cancel button in edit mode' ran for months with no `expect`
// or `verify` at all - it tapped back only if a back button happened to exist
// - so it could not fail. This scans every `test(` and `testWidgets(` body
// under test/ and fails on one with no assertion.
//
// What counts as an assertion: a call to `expect`, `expectLater`, any
// `verify*`, `fail`, any helper whose name starts with `expect` or `_expect`
// (the repository asserts through helpers such as `expectResultFailureType`),
// `meetsGuideline` or `matchesGoldenFile`. A skipped test is not judged.
//
// The one exception is a deliberate "must not throw" test, marked inside its
// body with a reason:
//
//     // no-assertion-ok: must not throw - <why that is the whole contract>

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowMarker = 'no-assertion-ok:';

final RegExp _testCall = RegExp(r'\b(?:test|testWidgets)\s*\(');
final RegExp _assertion = RegExp(
  r'\b(?:_?expect\w*|verify\w*|fail)\s*\(|\bmeetsGuideline\b|\bmatchesGoldenFile\b',
);
final RegExp _skip = RegExp(r'\bskip\s*:');

/// [source] with the contents of every string literal and comment replaced
/// by spaces, newlines kept, so offsets and line numbers still line up and
/// nothing quoted or commented can look like code.
String _blank(String source) {
  final out = StringBuffer();
  var i = 0;
  void blankTo(int end) {
    for (; i < end && i < source.length; i++) {
      out.write(source[i] == '\n' ? '\n' : ' ');
    }
  }

  while (i < source.length) {
    final c = source[i];
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      blankTo(end < 0 ? source.length : end);
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      blankTo(end < 0 ? source.length : end + 2);
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final quote = source.startsWith(c * 3, i) ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      var j = i;
      while (j < source.length && !source.startsWith(quote, j)) {
        j += !raw && source[j] == r'\' ? 2 : 1;
      }
      blankTo(j);
      out.write(quote);
      i += quote.length;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// The index just past the `)` closing the `(` at [open] in blanked [code].
int _closingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '(') depth++;
    if (code[i] == ')' && --depth == 0) return i + 1;
  }
  return code.length;
}

/// `path:line` for each test in [source] whose body asserts nothing.
List<String> _assertionless(String path, String source) {
  final code = _blank(source);
  final problems = <String>[];
  for (final match in _testCall.allMatches(code)) {
    final end = _closingParen(code, match.end - 1);
    final body = code.substring(match.end - 1, end);
    if (_assertion.hasMatch(body) ||
        _skip.hasMatch(body) ||
        source.substring(match.end - 1, end).contains(_allowMarker)) {
      continue;
    }
    final line = '\n'.allMatches(code.substring(0, match.start)).length + 1;
    problems.add('$path:$line');
  }
  return problems;
}

void main() {
  test('criterion 2: every test and testWidgets body asserts something', () {
    final files =
        Directory('test')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_test.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    final problems = [
      for (final f in files) ..._assertionless(f.path, f.readAsStringSync()),
    ];
    expect(
      problems,
      isEmpty,
      reason:
          'These tests cannot fail. Assert the outcome, or mark a deliberate '
          '"must not throw" test with "// $_allowMarker <reason>":\n'
          '${problems.join('\n')}',
    );
  });

  group('the scan itself', () {
    List<String> scan(String source) => _assertionless('x_test.dart', source);

    test('flags a body with no assertion, naming its line', () {
      final problems = scan('''
void main() {
  testWidgets('cancel (edit mode)', (tester) async {
    await tester.tap(find.byIcon(Icons.close));
  });
}''');
      expect(problems, ['x_test.dart:2']);
    });

    test('accepts expect, verify, fail and expect-named helpers', () {
      for (final call in const [
        'expect(a, b);',
        'await expectLater(f, completes);',
        'verifyNever(() => m());',
        'fail("x");',
        'expectResultFailureType(r, T);',
        '_expectSpansVersionChain(m);',
      ]) {
        expect(scan("test('t', () { $call });"), isEmpty, reason: call);
      }
    });

    test('ignores an assertion that only appears in a string or comment', () {
      expect(scan("test('expect( in a name', () { run(); });"), hasLength(1));
      expect(scan("test('t', () { run(); // expect(x)\n });"), hasLength(1));
    });

    test('skips skipped tests and honours the allow-list marker', () {
      expect(scan("test('t', () {}, skip: 'later');"), isEmpty);
      expect(
        scan("test('t', () { // $_allowMarker must not throw\n run(); });"),
        isEmpty,
      );
    });
  });
}
