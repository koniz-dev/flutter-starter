// Setup instructions that copy `.env` must also feed it to the build.
//
// `.env` is not a Flutter asset, so plain `flutter run` ignores it and runs on
// the built-in defaults. README and CONTRIBUTING drifted into exactly that
// (koniz-dev/flutter-starter#355); `tool/doc_env_runs.dart` is the rule that
// would have caught it, and `tool/check_docs.dart` runs it on every markdown
// diff (koniz-dev/flutter-starter#434). This test pins the rule's behaviour on
// fixtures and runs it over the repository from the Quality gate.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_env_runs.dart';

/// README.md lines 86-96 as they stood before #355.
const _readmeBefore = '''
### 4. Application Configuration
Initialize the local environment settings explicitly:
```bash
cp .env.example .env
```
_(Open `.env` and fill out backend specifics before compiling)_

### 5. Running
```bash
flutter run
```
''';

/// The same section after #355.
const _readmeAfter = '''
### 4. Application Configuration
Initialize the local environment settings explicitly:
```bash
cp .env.example .env
```
_(Open `.env` and fill out backend specifics before compiling)_

### 5. Running
```bash
flutter run --dart-define-from-file=.env
```
''';

void main() {
  group('findEnvRunProblems', () {
    test('fails on the pre-#355 README text', () {
      final problems = findEnvRunProblems(_readmeBefore, file: 'README.md');

      expect(problems, hasLength(1));
      expect(problems.single.line, 10);
      expect(problems.single.command, 'flutter run');
      expect(problems.single.toString(), startsWith('README.md:10: '));
    });

    test('passes on the fixed README text', () {
      expect(findEnvRunProblems(_readmeAfter), isEmpty);
    });

    test('flags flutter build too', () {
      const source = '```bash\ncp .env.example .env\nflutter build apk\n```\n';
      expect(findEnvRunProblems(source), hasLength(1));
    });

    test('joins a backslash-continued command before judging it', () {
      const source =
          '```bash\n'
          'cp .env.example .env\n'
          'flutter run \\\n'
          '  --dart-define-from-file=.env\n'
          '```\n';
      expect(findEnvRunProblems(source), isEmpty);
    });

    test('accepts explicit --dart-define= flags as a deliberate choice', () {
      const source =
          '```bash\n'
          'cp .env.example .env\n'
          'flutter run --dart-define=BASE_URL=https://api.example.com\n'
          '```\n';
      expect(findEnvRunProblems(source), isEmpty);
    });

    test('ignores prose and a commented-out command', () {
      const source =
          '```bash\n'
          'cp .env.example .env\n'
          '# flutter run would ignore the file\n'
          '```\n'
          'Plain `flutter run` will not pick the file up.\n'
          '```bash\n'
          'flutter run --dart-define-from-file=.env\n'
          '```\n';
      expect(findEnvRunProblems(source), isEmpty);
    });

    test('checks only the first run after the copy', () {
      const source =
          '```bash\n'
          'cp .env.example .env\n'
          'flutter run --dart-define-from-file=.env\n'
          'flutter run -d chrome\n'
          '```\n';
      expect(findEnvRunProblems(source), isEmpty);
    });

    test('a run with no preceding copy is not judged', () {
      expect(findEnvRunProblems('```bash\nflutter run\n```\n'), isEmpty);
    });
  });

  test('covers README.md and CONTRIBUTING.md as well as docs/', () {
    final paths = envRunFiles(
      Directory.current,
    ).map((f) => f.path.substring(Directory.current.path.length + 1)).toList();

    expect(paths, containsAll(<String>['README.md', 'CONTRIBUTING.md']));
    expect(paths.where((p) => p.startsWith('docs/')), isNotEmpty);
  });

  test('no document in the repository copies .env and then ignores it', () {
    expect(
      checkEnvRuns(Directory.current),
      0,
      reason:
          'Run `dart run tool/check_docs.dart --env-runs` for the list, then '
          'add --dart-define-from-file=.env to the command it names.',
    );
  });
}
