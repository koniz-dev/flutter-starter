// Lane code runs in fastlane/ (ios/fastlane/ on iOS), but fastlane runs every
// action from the project root (ios/). The upload lanes handed
// upload_to_play_store / upload_to_testflight a relative artifact path that
// the lane's File.exist? accepted and the action then resolved outside the
// repository, so every upload failed with "Could not find aab/ipa file". Each
// artifact path a lane builds must be absolute.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _assignment = RegExp(r'^\s*(\w+_path)\s*=\s*(.+)$', multiLine: true);

void main() {
  for (final fastfile in ['fastlane/Fastfile', 'ios/fastlane/Fastfile']) {
    test('$fastfile builds every artifact path with File.expand_path', () {
      final source = File(fastfile).readAsStringSync();
      final artifacts = [
        for (final m in _assignment.allMatches(source))
          if (RegExp(r'\.(aab|apk|ipa)"').hasMatch(m.group(2)!)) m,
      ];

      expect(artifacts, isNotEmpty, reason: 'no artifact path found');
      for (final m in artifacts) {
        expect(
          m.group(2),
          startsWith('File.expand_path('),
          reason: '${m.group(1)} in $fastfile',
        );
      }
    });
  }
}
