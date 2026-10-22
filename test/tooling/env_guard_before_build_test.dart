// Every `flutter build` in a workflow must run after the bundled-secrets
// guard.
//
// tool/check_env_assets.dart refuses a tree that would ship `.env` as a
// Flutter asset, but only the deploy workflows ran it; build.yml uploads a
// release APK and a web build without it. This reads every workflow job by
// job and fails when a `flutter build` line comes before the guard in its job.
//
// The two Fastfiles build release artifacts too, so they get the same check
// lane by lane.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _guard = 'dart run tool/check_env_assets.dart';
final RegExp _jobHeader = RegExp(r'^  ([A-Za-z0-9_-]+):\s*$');

/// `file:line` for each `flutter build` that runs before the guard in its job.
List<String> _unguardedBuilds(File workflow) {
  final problems = <String>[];
  var inJobs = false;
  var guarded = false;
  final lines = workflow.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('jobs:')) {
      inJobs = true;
      continue;
    }
    if (!inJobs) continue;
    if (_jobHeader.hasMatch(line)) {
      guarded = false;
      continue;
    }
    final code = line.trimLeft();
    if (code.startsWith('#')) continue;
    if (code.contains(_guard)) guarded = true;
    if (RegExp(r'\bflutter build\b').hasMatch(code) && !guarded) {
      problems.add('${workflow.path}:${i + 1}: $code');
    }
  }
  return problems;
}

final RegExp _laneHeader = RegExp(r'^\s*(?:private_)?lane\s+:\w+');

/// The Fastfiles that build release artifacts.
const _fastfiles = ['fastlane/Fastfile', 'ios/fastlane/Fastfile'];

/// `file:line` for each `flutter build` that runs before the guard in its
/// fastlane lane.
List<String> _unguardedLaneBuilds(File fastfile) {
  final problems = <String>[];
  var guarded = false;
  final lines = fastfile.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final code = lines[i].trimLeft();
    if (code.startsWith('#')) continue;
    if (_laneHeader.hasMatch(code)) {
      guarded = false;
      continue;
    }
    if (code.contains(_guard)) guarded = true;
    if (RegExp(r'\bflutter build\b').hasMatch(code) && !guarded) {
      problems.add('${fastfile.path}:${i + 1}: $code');
    }
  }
  return problems;
}

void main() {
  final workflows =
      Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('criterion 2: every flutter build in .github/workflows follows the '
      'guard in its job', () {
    final problems = [for (final w in workflows) ..._unguardedBuilds(w)];

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('criterion 1: build.yml runs the guard in each job that builds', () {
    final buildYml = workflows.singleWhere(
      (f) => f.path.endsWith('/build.yml'),
    );
    final text = buildYml.readAsStringSync();

    expect(RegExp(RegExp.escape(_guard)).allMatches(text), hasLength(4));
    expect(_unguardedBuilds(buildYml), isEmpty);
  });

  test('the scan sees the builds it should', () {
    // Guards the parser: build.yml does build, and an unguarded fixture is
    // caught.
    final fixture = File('${Directory.systemTemp.path}/unguarded_fixture.yml')
      ..writeAsStringSync('''
jobs:
  build:
    steps:
      # flutter build web   <- a comment, ignored
      - run: flutter build web
  safe:
    steps:
      - run: $_guard
      - run: flutter build apk
''');
    addTearDown(fixture.deleteSync);

    final problems = _unguardedBuilds(fixture);
    expect(problems, hasLength(1));
    expect(problems.single, contains('flutter build web'));
  });

  group('the Fastfiles', () {
    for (final path in _fastfiles) {
      test('criterion 2: every flutter build in $path follows the guard in '
          'its lane', () {
        final fastfile = File(path);
        final problems = _unguardedLaneBuilds(fastfile);

        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(
          RegExp(r'\bflutter build\b').allMatches(fastfile.readAsStringSync()),
          hasLength(2),
          reason: 'the scan must see both build lanes',
        );
      });
    }

    test('the lane scan catches an unguarded lane', () {
      final fixture = File('${Directory.systemTemp.path}/unguarded_Fastfile')
        ..writeAsStringSync('''
platform :android do
  lane :safe do
    sh("cd .. && $_guard")
    sh("cd .. && flutter build apk")
  end

  lane :unsafe do
    # sh("cd .. && flutter build ipa")   <- a comment, ignored
    sh("cd .. && flutter build appbundle")
  end
end
''');
      addTearDown(fixture.deleteSync);

      final problems = _unguardedLaneBuilds(fixture);
      expect(problems, hasLength(1));
      expect(problems.single, contains('flutter build appbundle'));
    });
  });
}
