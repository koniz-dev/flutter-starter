// Guard: every acceptance test builds its Riverpod container the way
// production does (koniz-dev/flutter-starter#288).
//
// Core declares the 401-refresh and session-termination seams, and the auth
// slice fills them through `authModuleOverrides`, which `createAppContainer`
// in lib/main.dart applies. A test that builds a bare `ProviderContainer`
// leaves those seams empty: a forced logout clears storage but never drops the
// in-memory session, so the router never moves to /login.
// forced_logout_acceptance_test.dart failed that way from #242 until #288, and
// nothing noticed, because the acceptance tests are tagged `golden` and skipped
// unless a run opts in with --run-skipped --tags golden. This scan is not
// tagged, so it runs in CI.
//
// The rule, per file under test/acceptance/:
//   * no `ProviderContainer(` at all - use
//     `createAppContainer(overrides: ...)`;
//   * every `ProviderScope(` must spread `authModuleOverrides` in its own
//     argument list, as `pumpAcceptance` does.
// `UncontrolledProviderScope(container: ...)` only hosts a container built
// elsewhere, so it is not a match.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One place a test builds a container its own way.
class ContainerViolation {
  const ContainerViolation(this.path, this.line, this.reason);

  final String path;
  final int line;
  final String reason;

  @override
  String toString() => '$path:$line  $reason';
}

final RegExp _bareContainer = RegExp(r'\bProviderContainer\s*\(');
final RegExp _scope = RegExp(r'\bProviderScope\s*\(');

/// [source] with every `//` comment blanked, keeping offsets and line numbers.
///
/// Comments are dropped so prose that names `ProviderContainer(` - like the
/// header above - is not code. String literals are left alone; a test that
/// spells a constructor call inside a string is not something to design for.
String _withoutLineComments(String source) => source.replaceAllMapped(
  RegExp('//[^\n]*'),
  (m) => ' ' * m.group(0)!.length,
);

/// The text between the `(` at [open] and its matching `)`.
String _argumentsFrom(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) {
        return source.substring(open + 1, i);
      }
    }
  }
  return source.substring(open + 1);
}

/// Every place in [source] (the file at [path]) that builds a container
/// without the production overrides.
List<ContainerViolation> scanAcceptanceSource(String path, String source) {
  final code = _withoutLineComments(source);
  int lineOf(int offset) =>
      '\n'.allMatches(code.substring(0, offset)).length + 1;

  return <ContainerViolation>[
    for (final m in _bareContainer.allMatches(code))
      ContainerViolation(
        path,
        lineOf(m.start),
        'builds a bare ProviderContainer; use createAppContainer(overrides: '
        '...) from package:flutter_starter/main.dart',
      ),
    for (final m in _scope.allMatches(code))
      if (!_argumentsFrom(code, m.end - 1).contains('authModuleOverrides'))
        ContainerViolation(
          path,
          lineOf(m.start),
          'builds a ProviderScope without authModuleOverrides; spread them '
          'first, as pumpAcceptance does',
        ),
  ];
}

void main() {
  group('scanAcceptanceSource', () {
    // The scanner proves itself on the shapes it must catch and must allow,
    // so a broken regex cannot turn the real scan below into a silent pass.
    test('flags a bare ProviderContainer, as #288 had it', () {
      const source = '''
final container = ProviderContainer(
  overrides: [storageServiceProvider.overrideWithValue(storage)],
);
''';

      expect(scanAcceptanceSource('a.dart', source).map((v) => v.line), [1]);
    });

    test('flags a ProviderScope that omits authModuleOverrides', () {
      const source = '''
await tester.pumpWidget(
  ProviderScope(overrides: overrides, child: const App()),
);
''';

      expect(scanAcceptanceSource('a.dart', source).map((v) => v.line), [2]);
    });

    test('allows createAppContainer, UncontrolledProviderScope and a scope '
        'that spreads authModuleOverrides', () {
      const source = '''
final container = createAppContainer(overrides: [a]);
await tester.pumpWidget(
  UncontrolledProviderScope(container: container, child: const App()),
);
await tester.pumpWidget(
  ProviderScope(
    overrides: <Override>[...authModuleOverrides, ...overrides],
    child: MaterialApp(home: Builder(builder: (c) => const Text('x'))),
  ),
);
''';

      expect(scanAcceptanceSource('a.dart', source), isEmpty);
    });

    test('ignores ProviderContainer( written in a comment', () {
      const source = '// never call ProviderContainer( here\nfinal x = 1;\n';

      expect(scanAcceptanceSource('a.dart', source), isEmpty);
    });
  });

  test('every acceptance test builds its container the production way', () {
    final files =
        Directory('test/acceptance')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'run from the package root');

    final violations = <ContainerViolation>[
      for (final file in files)
        ...scanAcceptanceSource(file.path, file.readAsStringSync()),
    ];

    expect(
      violations.map((v) => '$v'),
      isEmpty,
      reason:
          "Without authModuleOverrides, core's session seams are empty and "
          'a forced logout never reaches the router - the #288 failure, which '
          'stays invisible because acceptance tests are skipped in CI.',
    );
  });
}
