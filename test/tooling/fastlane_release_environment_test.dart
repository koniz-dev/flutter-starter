// The Fastfile release lanes took environment as free text, so
// environment:development built a release that refuses to start
// (build_all.sh and build.yml already refused it). And get_version required
// "+build", aborting build_bundle on `version: 1.0.0`, a form bump_version.sh
// writes.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final bool _hasRuby = () {
  try {
    return Process.runSync('ruby', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

const _fastfiles = ['fastlane/Fastfile', 'ios/fastlane/Fastfile'];

/// Runs [code] in Ruby with fastlane/release_environment.rb loaded.
String _ruby(String code) {
  final result = Process.runSync('ruby', [
    '-e',
    'require File.expand_path("fastlane/release_environment"); $code',
  ]);
  return '${result.stdout}${result.stderr}';
}

void main() {
  final skip = _hasRuby ? null : 'ruby is not installed';

  test('only staging and production pass, trimmed and lowercased', () {
    expect(
      _ruby('print ReleaseEnvironment.normalize(" Production ")'),
      'production',
    );
    expect(_ruby('print ReleaseEnvironment.normalize("staging")'), 'staging');
    for (final value in ['development', 'prod', '']) {
      expect(
        _ruby(
          'begin; ReleaseEnvironment.normalize("$value"); print "passed"; '
          'rescue ArgumentError => e; print "refused"; end',
        ),
        'refused',
        reason: value,
      );
    }
  }, skip: skip);

  for (final path in _fastfiles) {
    final source = File(path).readAsStringSync();

    test('every build lane in $path validates its environment', () {
      for (final lane in RegExp(
        r'lane :(build_\w+) do[\s\S]*?\n  end',
      ).allMatches(source)) {
        expect(
          lane.group(0),
          contains('ReleaseEnvironment.lane_value('),
          reason: lane.group(1),
        );
      }
    });

    test('get_version in $path accepts a version without a build number', () {
      final pattern = RegExp(r'pubspec\.match\(/(.+)/\)').firstMatch(source)!;
      final ruby =
          '''
m = "name: x\\nversion: 1.2.3\\n".match(/${pattern.group(1)}/)
print m ? m[1] : "no match"
''';
      final result = Process.runSync('ruby', ['-e', ruby]);
      expect('${result.stdout}', '1.2.3');
    }, skip: skip);
  }
}
