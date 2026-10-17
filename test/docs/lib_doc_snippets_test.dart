// Doc-comment examples in lib/ marked `// compile` must compile
// (koniz-dev/flutter-starter#362).
//
// The performance mixins' usage examples named a `PerformanceService` type
// that does not exist, wrote `implements X with Y` (a syntax error), and in
// the repository example never overrode `performanceService` - so even fixed,
// the mixin's default `null` meant it traced nothing. A ```dart block in a
// `///` comment whose first line is `// compile` is now extracted and
// analyzed: zero errors and zero warnings.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _marker = '// compile';

/// The `// compile`-marked ```dart blocks in the `///` comments of [source].
List<String> _markedBlocks(String source) {
  final blocks = <String>[];
  List<String>? current;
  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trimLeft();
    if (!line.startsWith('///')) {
      current = null;
      continue;
    }
    final text = line.length > 3 && line[3] == ' '
        ? line.substring(4)
        : line.substring(3);
    if (current == null) {
      if (text.trim() == '```dart') current = [];
      continue;
    }
    if (text.trim() == '```') {
      if (current.isNotEmpty && current.first.trim() == _marker) {
        blocks.add(current.skip(1).join('\n'));
      }
      current = null;
      continue;
    }
    current.add(text);
  }
  return blocks;
}

void main() {
  final sources = {
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')))
      f.path: f.readAsStringSync(),
  };

  test('criterion 1: every // compile doc example in lib/ analyzes with no '
      'error or warning', () {
    final blocks = [
      for (final MapEntry(key: path, value: source) in sources.entries)
        for (final (i, block) in _markedBlocks(source).indexed)
          (name: '${path.replaceAll(RegExp('[/.]'), '_')}_$i', code: block),
    ];
    expect(blocks, isNotEmpty);

    // Inside the project so package: imports resolve; removed afterwards.
    final dir = Directory('test/docs/_lib_doc_snippets')..createSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final b in blocks) {
      File('${dir.path}/${b.name}.dart').writeAsStringSync('${b.code}\n');
    }

    final result = Process.runSync('dart', [
      'analyze',
      '--format=machine',
      dir.path,
    ]);
    final problems = const LineSplitter()
        .convert('${result.stdout}${result.stderr}')
        .where((l) => l.startsWith('ERROR|') || l.startsWith('WARNING|'))
        .toList();
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  for (final path in const [
    'lib/core/performance/performance_usecase_mixin.dart',
    'lib/core/performance/performance_repository_mixin.dart',
  ]) {
    test('criterion 1: $path has a compiled example that overrides '
        'performanceService', () {
      final blocks = _markedBlocks(sources[path]!);
      expect(blocks, isNotEmpty, reason: 'the example must be marked');
      expect(
        blocks.any(
          (b) => RegExp(
            r'@override\s+IPerformanceService\??\s+get\s+performanceService',
          ).hasMatch(b),
        ),
        isTrue,
        reason: "without the override the mixin's default null traces nothing",
      );
    });
  }

  test('the extractor reads a marked block and skips unmarked ones', () {
    const source = '''
/// ```dart
/// // compile
/// final a = 1;
/// ```
///
/// ```dart
/// final b = 2;
/// ```
class X {}
''';
    expect(_markedBlocks(source), ['final a = 1;']);
  });
}
