// Pinning is on in staging and production, and a release built with pinning
// on and no fingerprints refuses to start. The Fastfile release lanes passed
// only ENVIRONMENT and BASE_URL, so every build they made would not open.
// Each `flutter build` they run must now carry the pinning defines from
// fastlane/ssl_pinning.rb, and every lane that calls a build lane must
// forward the pinning options to it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fastfiles = ['fastlane/Fastfile', 'ios/fastlane/Fastfile'];

/// Each `sh(...)` call in [source] that runs `flutter build`, as one string.
List<String> _flutterBuilds(String source) => [
  for (final m in RegExp(
    r'sh\("[^"]*flutter build[\s\S]*?"\)',
  ).allMatches(source))
    m.group(0)!,
];

void main() {
  for (final path in _fastfiles) {
    final source = File(path).readAsStringSync();

    test('$path loads the pinning helper', () {
      expect(
        source,
        matches(RegExp(r"require_relative '[./]*\S*ssl_pinning'")),
      );
    });

    test('every flutter build in $path carries the pinning defines', () {
      final builds = _flutterBuilds(source);
      expect(builds, isNotEmpty);
      for (final build in builds) {
        expect(build, contains('#{pinning}'), reason: build);
      }
      expect(
        'SslPinning.lane_defines('.allMatches(source).length,
        builds.length,
        reason: 'each build computes its defines',
      );
    });

    test('every call of a build lane in $path forwards the pinning '
        'options', () {
      final calls = RegExp(
        r'= build_(bundle|apk|appstore|adhoc)\(([^)]*)\)',
      ).allMatches(source).toList();
      expect(calls, isNotEmpty, reason: 'no build-lane call found');
      for (final call in calls) {
        expect(
          call.group(2),
          contains('options.slice(:ssl_fingerprints, :ssl_pinning'),
          reason: call.group(0),
        );
      }
    });
  }
}
