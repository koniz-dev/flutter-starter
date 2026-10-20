// `mason get` writes `.mason/bricks.json` and `mason-lock.json`, both holding
// absolute paths on the machine that ran it, and neither was ignored - the
// next `git add -A` committed one developer's local paths
// (koniz-dev/flutter-starter#340). evidence:docs/verification/issue-340 runs a real
// `mason get` in a fresh clone; this pins the ignore rules it relies on.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final path in const [
    '.mason/bricks.json',
    '.mason/bricks/feature_clean/brick.yaml',
    'mason-lock.json',
  ]) {
    test('criterion 1: git ignores $path', () {
      final result = Process.runSync('git', ['check-ignore', '-q', path]);

      expect(
        result.exitCode,
        0,
        reason: '`git check-ignore $path` exited ${result.exitCode}',
      );
    });
  }

  test('the bricks themselves are not ignored', () {
    final result = Process.runSync('git', [
      'check-ignore',
      '-q',
      'bricks/feature_clean/brick.yaml',
    ]);

    expect(result.exitCode, 1, reason: 'mason.yaml points at tracked bricks');
  });
}
