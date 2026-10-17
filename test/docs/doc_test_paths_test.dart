// `flutter test <path>` in the docs must name a real file
// (koniz-dev/flutter-starter#551, split from #360).

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
