// The iOS app icon must be generated without an alpha channel
// (koniz-dev/flutter-starter#339).
//
// flutter_launcher_icons.yaml set `ios: true` without `remove_alpha_ios`, so
// branding with a PNG logo - which normally has alpha - produced an RGBA 1024
// icon that App Store Connect rejects, while the generator still exited 0.
// evidence:docs/verification/issue-339/alpha_probe.sh runs the real generator on an
// RGBA logo; this pins the setting that makes it pass.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flutter_launcher_icons.yaml flattens alpha whenever it generates iOS '
      'icons', () {
    final config = File('flutter_launcher_icons.yaml').readAsStringSync();

    final generatesIos = RegExp(
      r'^\s+ios:\s*true\b',
      multiLine: true,
    ).hasMatch(config);
    final removesAlpha = RegExp(
      r'^\s+remove_alpha_ios:\s*true\b',
      multiLine: true,
    ).hasMatch(config);

    expect(generatesIos, isTrue, reason: 'the template generates iOS icons');
    expect(
      removesAlpha,
      isTrue,
      reason:
          'an RGBA logo would yield an RGBA iOS icon, which App Store '
          'Connect rejects',
    );
  });
}
