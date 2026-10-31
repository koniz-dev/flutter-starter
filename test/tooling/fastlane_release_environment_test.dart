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

    test('every lane in $path validates its environment', () {
      final assignments = RegExp(
        r'^\s*environment = (.+)$',
        multiLine: true,
      ).allMatches(source).toList();
      expect(assignments, isNotEmpty);
      for (final assignment in assignments) {
        expect(
          assignment.group(1),
          startsWith('ReleaseEnvironment.lane_value('),
          reason: assignment.group(0),
        );
      }
    });

    final pattern = RegExp(r'pubspec\.match\(/(.+)/\)').firstMatch(source)!;
    const versions = {
      '1.2.3': '1.2.3 1',
      '1.2.3+45': '1.2.3 45',
      '1.2.3+45 # bumped': '1.2.3 45',
      // A prerelease would read as 1.0.0 build 1: refuse it instead.
      '1.0.0-beta+7': 'no match',
    };
    for (final MapEntry(key: version, value: expected) in versions.entries) {
      test('get_version in $path reads "$version" as $expected', () {
        final regex = pattern.group(1);
        final pubspec = 'name: x\\nversion: $version\\n';
        final ruby =
            'm = "$pubspec".match(/$regex/); '
            'print m ? "#{m[1]} #{m[2] || "1"}" : "no match"';
        final result = Process.runSync('ruby', ['-e', ruby]);
        expect('${result.stdout}${result.stderr}', expected);
      }, skip: skip);
    }
  }
}
