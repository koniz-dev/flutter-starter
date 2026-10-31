// `flutter test <path>` in the docs must name a real file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_test_paths.dart';

void main() {
  bool real(String path) => const {
    'test/features/auth/domain/usecases/login_usecase_test.dart',
    'test/core/storage/migration/',
    'test/core/storage/storage_migration_service_test.dart',
    'test/acceptance/',
  }.contains(path);

  List<String> missing(String markdown) => [
    for (final p in findMissingTestPaths(markdown, real)) p.path,
  ];

  test(
    'a fence inside a longer or other-character fence does not close it',
    () {
      // CommonMark: a ``` line inside a ~~~ or ```` block is content, so the
      // commands below are inside a fence and are checked.
      const source =
          '~~~markdown\n'
          '```bash\n'
          'flutter test test/a_test.dart\n'
          '```\n'
          '~~~\n'
          '\n'
          '````\n'
          '```\n'
          'flutter test test/b_test.dart\n'
          '```\n'
          '````\n';

      final missing = findMissingTestPaths(source, (_) => false);

      expect(missing.map((m) => m.path), [
        'test/a_test.dart',
        'test/b_test.dart',
      ]);
    },
  );

  test('a block ending in a backslash does not swallow its closing fence', () {
    // ASCII art whose last line ends in `\\`, then prose, then a command.
    const source =
        '```text\n  /____\\\n```\n'
        '\n'
        'Prose: `flutter test --coverage`, as CI does.\n'
        '\n'
        '```bash\n'
        'flutter test test/nope_test.dart\n'
        '```\n';

    final missing = findMissingTestPaths(source, (_) => false);

    expect(missing.map((m) => m.path), ['test/nope_test.dart']);
    expect(missing.single.line, 8);
  });

  test('covers README.md, CONTRIBUTING.md and CLAUDE.md as well as docs/', () {
    final paths = testPathFiles(
      Directory.current,
    ).map((f) => f.path.substring(Directory.current.path.length + 1)).toList();

    expect(
      paths,
      containsAll(<String>['README.md', 'CONTRIBUTING.md', 'CLAUDE.md']),
    );
    expect(paths.where((p) => p.startsWith('docs/')), isNotEmpty);
  });

  test('criterion 2: the path CONTRIBUTING used to name fails', () {
    const before = '''
```bash
flutter test test/features/auth/domain/usecases/login_test.dart
```
''';
    expect(missing(before), [
      'test/features/auth/domain/usecases/login_test.dart',
    ]);
  });

  test('criterion 2: the real path passes', () {
    const after = '''
```bash
flutter test test/features/auth/domain/usecases/login_usecase_test.dart
```
''';
    expect(missing(after), isEmpty);
  });

  test('skips flags, flag values, placeholders and prose outside fences', () {
    const markdown = '''
Run `flutter test test/not/in/a/fence.dart` from the root.

```bash
flutter test --timeout=5m --tags golden -r expanded test/acceptance/
flutter test test/path/to/test.dart
flutter test test/features/<name>/
flutter test # all of it
```
''';
    expect(missing(markdown), isEmpty);
  });

  test('joins a backslash-continued command and checks every path', () {
    const markdown = r'''
```bash
flutter test test/core/storage/migration/ \
  test/core/storage/storage_migration_service_test.dart \
  test/core/storage/gone_test.dart
```
''';
    final problems = findMissingTestPaths(markdown, real);
    expect(problems.map((p) => p.path), ['test/core/storage/gone_test.dart']);
    expect(problems.single.line, 2, reason: 'reported at the command start');
  });

  test('checks a path with a :line suffix without the suffix', () {
    const markdown = '''
```bash
flutter test test/features/auth/domain/usecases/login_usecase_test.dart:12
```
''';
    expect(missing(markdown), isEmpty);
  });
}
