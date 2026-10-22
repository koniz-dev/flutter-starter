// Every public helper in test/helpers/ must have a caller.
//
// About 50 shared helpers had no reference anywhere, including three that
// were broken in ways no caller would have survived: findWidgetWithText
// matched only Text, findTextFormFieldByLabel returned a Text, and
// waitForCondition polled DateTime.now() under testWidgets' fake clock.
// Adopters copy these helpers. A public top-level symbol declared in a
// test/helpers/ library must be referenced from test/ (outside the library
// that declares it), integration_test/ or tool/.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _declaration = RegExp(
  r'^(?:abstract\s+|final\s+|base\s+|sealed\s+)*(?:class|mixin|enum|extension)\s+([A-Za-z]\w*)'
  r'|^(?:final|const|var)\s+(?:[\w<>?,\s]+\s)?([a-zA-Z]\w*)\s*='
  r'|^[A-Za-z_][\w<>?,\s\[\]]*?\s([a-zA-Z]\w*)\s*(?:<[^>]*>)?\s*\(',
  multiLine: true,
);

/// The public top-level names [source] declares.
Set<String> _publicDeclarations(String source) => {
  for (final m in _declaration.allMatches(source))
    for (final g in [m.group(1), m.group(2), m.group(3)])
      if (g != null && g != 'main') g,
};

List<File> _dartFiles(String root) => !Directory(root).existsSync()
    ? const []
    : Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

void main() {
  test('criterion 2: every public helper in test/helpers/ has a caller', () {
    final libraries = Directory('test/helpers')
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.dart') && !f.path.endsWith('_test.dart'),
        )
        .toList();
    expect(libraries, isNotEmpty);

    final elsewhere = [
      for (final root in const ['test', 'integration_test', 'tool'])
        ..._dartFiles(root),
    ];
    final unused = <String>[];
    for (final library in libraries) {
      // Comments do not count as a use: a helper named only in a comment
      // explaining its removal is still unused.
      final corpus = [
        for (final f in elsewhere)
          if (f.path != library.path)
            f.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), ''),
      ].join('\n');
      for (final name in _publicDeclarations(library.readAsStringSync())) {
        if (!RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(corpus)) {
          unused.add('${library.path}: $name');
        }
      }
    }

    expect(
      unused,
      isEmpty,
      reason:
          'Use it in a test (a test of the helper itself counts) or delete '
          'it:\n${unused.join('\n')}',
    );
  });

  test('the declaration scan sees functions, classes and variables', () {
    const source = '''
class FakeThing {}
final fixture = 1;
Widget buildThing({int a = 1}) => const SizedBox();
Future<void> pumpThing(WidgetTester tester) async {}
void _private() {}
''';
    expect(
      _publicDeclarations(source),
      {'FakeThing', 'fixture', 'buildThing', 'pumpThing'},
    );
  });
}
