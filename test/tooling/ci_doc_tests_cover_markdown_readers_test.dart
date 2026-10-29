// A docs-only pull request skips format, analyze and the full suite in the
// Quality gate, but some tests read markdown - CLAUDE.md's checks table, the
// upgrade guide's version marker, strip markers, doc snippets and links. A
// doc they parse used to merge broken on a green gate and turn the next code
// pull request red. ci.yml now runs those tests on a docs-only change, from
// the `DOC_TESTS` list; this keeps the list from falling behind.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The paths `DOC_TESTS` lists in ci.yml's "Run the tests that read
/// markdown" step.
List<String> _docTestPaths() {
  final ci = File('.github/workflows/ci.yml').readAsLinesSync();
  final start = ci.indexWhere((l) => l.trim() == 'DOC_TESTS: >-');
  expect(start, isNot(-1), reason: 'ci.yml no longer declares DOC_TESTS');
  final indent = ci[start + 1].length - ci[start + 1].trimLeft().length;
  return [
    for (final line in ci.skip(start + 1))
      if (line.trim().isEmpty || line.length - line.trimLeft().length < indent)
        null
      else
        line.trim(),
  ].takeWhile((p) => p != null).cast<String>().toList();
}

/// A test that names a markdown file, or filters files by the `.md` suffix.
final RegExp _readsMarkdown = RegExp(r"""\.md['"]""");

void main() {
  test('every test that reads markdown runs on a docs-only change', () {
    final paths = _docTestPaths();
    expect(paths, isNotEmpty);
    for (final path in paths) {
      expect(
        FileSystemEntity.typeSync(path),
        isNot(FileSystemEntityType.notFound),
        reason: 'DOC_TESTS lists $path, which does not exist',
      );
    }

    final uncovered = [
      for (final file in Directory('test').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('_test.dart') &&
            _readsMarkdown.hasMatch(file.readAsStringSync()) &&
            !paths.any((p) => file.path == p || file.path.startsWith('$p/')))
          file.path,
    ];

    expect(
      uncovered,
      isEmpty,
      reason:
          'These tests read markdown but a docs-only pull request would not '
          'run them. Add them to DOC_TESTS in .github/workflows/ci.yml.',
    );
  });
}
