// Every shell script and git hook must pass `shellcheck -S warning`
// (koniz-dev/flutter-starter#302).
//
// Nothing in CI ran shellcheck, so warnings - an unused variable, an
// unchecked `cd` - accumulated unseen. This runs it under `flutter test`, which
// the Quality gate runs on every PR. ubuntu-latest ships shellcheck; a
// developer machine may not, so the test skips locally when the binary is
// missing but fails under CI (`CI=true`), where a skip would hide the gate.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _hasShellcheck() {
  try {
    return Process.runSync('shellcheck', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// The scripts under `scripts/` and the hooks under `.githooks/`.
List<String> _shellFiles() {
  final files = <String>[
    if (Directory('scripts').existsSync())
      for (final f in Directory('scripts').listSync(recursive: true))
        if (f is File && f.path.endsWith('.sh')) f.path,
    if (Directory('.githooks').existsSync())
      for (final f in Directory('.githooks').listSync())
        if (f is File) f.path,
  ];
  return files..sort();
}

void main() {
  final available = _hasShellcheck();
  final inCi = Platform.environment['CI'] == 'true';

  test(
    'shellcheck -S warning passes on scripts/ and .githooks/',
    skip: !available && !inCi
        ? 'shellcheck is not installed; CI runs this check'
        : null,
    () {
      expect(
        available,
        isTrue,
        reason: 'CI must have shellcheck: a skipped gate is no gate',
      );
      final files = _shellFiles();
      expect(files, isNotEmpty);
      expect(files, contains('scripts/ci/generate_changelog.sh'));

      final result = Process.runSync('shellcheck', ['-S', 'warning', ...files]);

      expect(
        result.exitCode,
        0,
        reason: 'shellcheck findings:\n${result.stdout}${result.stderr}',
      );
    },
  );
}
