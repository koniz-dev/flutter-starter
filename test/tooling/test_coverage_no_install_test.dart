// `test_coverage.sh --html` ran `brew install lcov` or `sudo apt-get install`
// on its own when genhtml was missing, and no doc said so. Installing
// software is the user's call: the script now stops and prints the command.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test_coverage.sh installs nothing; it names the install command', () {
    final script = File('scripts/test/test_coverage.sh').readAsStringSync();
    final installs = [
      for (final line in script.split('\n'))
        if (RegExp(r'^\s*(sudo\s+)?(brew|apt-get|apt)\s').hasMatch(line))
          line.trim(),
    ];

    expect(installs, isEmpty);
    expect(script, contains('echo "  macOS:  brew install lcov"'));
  });
}
