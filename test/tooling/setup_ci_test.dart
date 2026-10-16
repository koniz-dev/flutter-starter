// setup_ci.dart must enable exactly one deploy option, and a deploy run that
// built nothing must not go green (koniz-dev/flutter-starter#334).
//
// The deploy workflows document tag-push and main-push deploys as
// alternatives, but their commented `push:` block lists both, and
// setup_ci.dart uncommented the whole block: every push to main deployed, as
// production. Their upload steps also had no `if-no-files-found: error`, so
// with the build steps still commented a run was green with zero artifacts.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final List<File> _deployWorkflows =
    Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('deploy-'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  late Directory copy;

  setUp(() {
    copy = Directory.systemTemp.createTempSync('setup_ci_test');
    for (final file in Directory('.github/workflows').listSync()) {
      if (file is File) {
        file.copySync('${copy.path}/${file.uri.pathSegments.last}');
      }
    }
  });

  tearDown(() => copy.deleteSync(recursive: true));

  Future<ProcessResult> setupCi(List<String> args) => Process.run('dart', [
    'scripts/dev/setup_ci.dart',
    '--dir',
    copy.path,
    ...args,
  ]);

  /// The live (uncommented) lines of [name]'s top-level `on:` block.
  List<String> liveTriggers(String name) {
    final lines = File('${copy.path}/$name').readAsLinesSync();
    final start = lines.indexWhere((l) => l.startsWith('on:'));
    final end = lines.indexWhere(
      (l) => l.isNotEmpty && !l.startsWith(' '),
      start + 1,
    );
    return lines
        .sublist(start + 1, end)
        .where((l) => !l.trimLeft().startsWith('#') && l.trim().isNotEmpty)
        .map((l) => l.trim())
        .toList();
  }

  test('there are deploy workflows to check', () {
    expect(_deployWorkflows, hasLength(3));
  });

  group('criterion 1: setup_ci.dart enables exactly one deploy option', () {
    test(
      'without --deploy-trigger, no deploy workflow gets a push trigger',
      () async {
        final result = await setupCi(['--dry-run']);

        expect(result.exitCode, 0);
        expect(result.stdout, isNot(contains('would enable in deploy-')));
        expect(result.stdout, contains('deploy workflow left manual-only'));
      },
    );

    test('--deploy-trigger=tags enables tags and not branches', () async {
      final dry = await setupCi(['--dry-run', '--deploy-trigger=tags']);
      expect(dry.stdout, contains('would enable in deploy-android.yml'));
      expect(dry.stdout, isNot(contains('branches:')));

      await setupCi(['--yes', '--deploy-trigger=tags']);
      for (final f in _deployWorkflows) {
        final name = f.uri.pathSegments.last;
        final live = liveTriggers(name);
        expect(live, containsAll(['push:', 'tags:']), reason: name);
        expect(
          live.any((l) => l.startsWith('branches:')),
          isFalse,
          reason: name,
        );
      }
    });

    test('--deploy-trigger=branch enables branches and not tags', () async {
      final dry = await setupCi(['--dry-run', '--deploy-trigger=branch']);
      expect(dry.stdout, contains('branches: [ main ]'));
      expect(dry.stdout, isNot(contains('tags:')));

      await setupCi(['--yes', '--deploy-trigger=branch']);
      for (final f in _deployWorkflows) {
        final name = f.uri.pathSegments.last;
        final live = liveTriggers(name);
        expect(live, contains('push:'), reason: name);
        expect(
          live.any((l) => l.startsWith('branches:')),
          isTrue,
          reason: name,
        );
        expect(live.any((l) => l.startsWith('tags:')), isFalse, reason: name);
      }
    });

    test('an unknown value is refused and writes nothing', () async {
      final before = File('${copy.path}/deploy-android.yml').readAsStringSync();
      final result = await setupCi(['--yes', '--deploy-trigger=both']);

      expect(result.exitCode, 64);
      expect(
        File('${copy.path}/deploy-android.yml').readAsStringSync(),
        before,
      );
    });
  });

  group('criterion 2: every deploy upload fails on zero files', () {
    for (final f in _deployWorkflows) {
      final name = f.uri.pathSegments.last;
      test(name, () {
        final steps = f.readAsStringSync().split(RegExp(r'\n\s+- name: '));
        final uploads = steps.where(
          (s) => s.contains('uses: actions/upload-artifact@'),
        );
        for (final step in uploads) {
          expect(step, contains('if-no-files-found: error'), reason: step);
        }
      });
    }
  });

  group('criterion 3: commented artifact paths use the flavorless layout', () {
    for (final f in _deployWorkflows) {
      final name = f.uri.pathSegments.last;
      test(name, () {
        final text = f.readAsStringSync();
        expect(text, isNot(contains(r'${ENV}Release')), reason: name);
        expect(text, isNot(contains(r'app-${ENV}-release')), reason: name);
        if (text.contains('releaseFiles:')) {
          expect(
            text,
            contains(
              'releaseFiles: build/app/outputs/bundle/release/app-release.aab',
            ),
          );
        }
      });
    }
  });
}
