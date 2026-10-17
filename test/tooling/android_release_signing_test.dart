// A workflow that builds an Android release must provision a signing key
// (koniz-dev/flutter-starter#344).
//
// android/app/build.gradle.kts refuses an unsigned or debug-signed release
// (#132). build.yml mints a throwaway key for its release APK; the
// scripts-smoke build-all job ran scripts/ci/build_all.sh, which builds
// release artifacts, without one, so it could not pass. This reads every
// workflow job by job and fails when a job builds an Android release without
// writing android/key.properties first. Commented-out template steps (the
// deploy workflows) do not count either way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _jobHeader = RegExp(r'^  ([A-Za-z0-9_-]+):\s*$');

/// Whether the (uncommented) [line] builds an Android release.
bool _buildsAndroidRelease(String line) {
  if (line.contains('build_all.sh')) return true;
  if (RegExp(r'\bflutter build appbundle\b').hasMatch(line)) return true;
  return RegExp(r'\bflutter build apk\b').hasMatch(line) &&
      !line.contains('--debug') &&
      !line.contains('--profile');
}

/// `workflow:line` for each Android release build with no signing key
/// written earlier in its job.
List<String> _unsignedReleaseBuilds(String path, String source) {
  final problems = <String>[];
  var inJobs = false;
  var keyed = false;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('jobs:')) {
      inJobs = true;
      continue;
    }
    if (!inJobs) continue;
    if (_jobHeader.hasMatch(line)) {
      keyed = false;
      continue;
    }
    final code = line.trimLeft();
    // Comments and display names are not commands.
    if (code.startsWith('#') || RegExp(r'^(?:- )?name:').hasMatch(code)) {
      continue;
    }
    if (code.contains('android/key.properties')) keyed = true;
    if (_buildsAndroidRelease(code) && !keyed) {
      problems.add('$path:${i + 1}: $code');
    }
  }
  return problems;
}

void main() {
  test('criterion 2: every Android release build in a workflow follows a '
      'signing key in its job', () {
    final workflows =
        Directory('.github/workflows')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.yml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(workflows, isNotEmpty);

    final problems = [
      for (final w in workflows)
        ..._unsignedReleaseBuilds(w.path, w.readAsStringSync()),
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the scan catches an unsigned release build and passes a keyed one', () {
    const source = '''
jobs:
  unsigned:
    name: build_all.sh (production)
    steps:
      - run: ./scripts/ci/build_all.sh production
  signed:
    steps:
      - run: echo "storeFile=k.jks" > android/key.properties
      - run: flutter build appbundle --release
  debug:
    steps:
      - run: flutter build apk --debug
  template:
    steps:
      # - run: flutter build appbundle
''';
    final problems = _unsignedReleaseBuilds('x.yml', source);
    expect(problems, hasLength(1));
    expect(problems.single, contains('build_all.sh'));
  });
}
