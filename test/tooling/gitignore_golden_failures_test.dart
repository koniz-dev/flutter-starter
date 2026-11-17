// A failed golden comparison writes its diff images into a `failures/`
// directory next to the test, and nothing ignored it, so they showed up as
// untracked files ready to be committed. Only test/ is ignored: a
// `failures/` directory under lib/ (a domain's failure types) is source.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _ignored(String path) =>
    Process.runSync('git', [
      'check-ignore',
      '--no-index',
      '-q',
      path,
    ]).exitCode ==
    0;

void main() {
  test('golden failure images under test/ are ignored', () {
    for (final path in [
      'test/acceptance/failures/login_masterImage.png',
      'test/features/auth/presentation/failures/x_isolatedDiff.png',
    ]) {
      expect(_ignored(path), isTrue, reason: path);
    }
  });

  test('a failures/ directory under lib/ is not ignored', () {
    expect(
      _ignored('lib/features/orders/domain/failures/order_failure.dart'),
      isFalse,
    );
  });
}
