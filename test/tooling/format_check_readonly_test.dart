// A format check must report, not rewrite.
//
// `format_dart.sh --check` ran `dart format --set-exit-if-changed` without
// `--output=none`, so the "check" reformatted the working tree and exited 1;
// the acceptance runner's format gate did the same. The behaviour is proven by
// scripts/test/format_check_test.sh against a scratch copy of the tree; this
// runs it under `flutter test`, so every CI run exercises it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'criteria 1-2: scripts/test/format_check_test.sh passes',
    () {
      final result = Process.runSync('bash', [
        'scripts/test/format_check_test.sh',
      ]);

      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, contains('working tree unchanged: yes'));
      expect(result.stdout, contains('formatted the file'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
