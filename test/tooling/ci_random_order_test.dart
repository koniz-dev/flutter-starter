// The Quality gate runs the suite in a random order and names the seed, so an
// order-dependent test fails a PR with a reproducible command
// (koniz-dev/flutter-starter#462; #370 and #602 were order-dependent tests
// that only a shuffled run exposed).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final ci = File('.github/workflows/ci.yml').readAsStringSync();
  final step = RegExp(
    r'- name: Run tests \(random order\)\n(.*?)(?=\n      - name: |\n\S|$)',
    dotAll: true,
  ).firstMatch(ci)?.group(1);

  test('criterion 1: the Quality gate runs flutter test in a random order', () {
    expect(step, isNotNull, reason: 'ci.yml has no "Run tests (random order)"');
    expect(step, contains('flutter test'));
    expect(step, contains('--test-randomize-ordering-seed random'));
    // The seed flutter picked is extracted from its own output and printed.
    expect(step, contains('test-randomize-ordering-seed=[0-9]*'));
    expect(step, contains('Test order seed:'));
  });

  test(
    'criterion 2: a failure names the seed with the command to reproduce',
    () {
      expect(step, contains(r'if [ "$status" -ne 0 ]'));
      expect(
        step,
        contains(
          r'flutter test --test-randomize-ordering-seed ${seed:-unknown}',
        ),
      );
      expect(step, contains(r'exit "$status"'));
    },
  );

  test('no other step runs the suite in file order', () {
    final plain = RegExp('run: flutter test(?! --test-randomize)');
    expect(plain.hasMatch(ci), isFalse);
  });
}
