// Relative links in markdown are checked by `tool/check_docs.dart`, which the
// Docs check runs on a markdown diff. A diff that renames or deletes a file a
// document links to touches no markdown, so nothing checked the link: `main`
// kept it broken until the next, unrelated docs pull request failed for it.
//
// This test runs the same link check on the real tree, so the Quality gate
// catches that direction, as doc_symbols_test.dart does for identifiers.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository's package config: `dart <file>` with it skips `dart run`'s
/// build-hook step, whose native-asset bundling crashed when several tests
/// ran it at once.
final String _packages = File(
  '.dart_tool/package_config.json',
).absolute.path;

void main() {
  test('every relative link and anchor in the markdown resolves', () {
    final result = Process.runSync('dart', [
      '--packages=$_packages',
      'tool/check_docs.dart',
      '--links',
    ]);

    expect(
      result.exitCode,
      0,
      reason:
          'A markdown link points at a path or anchor that does not exist. '
          'If you renamed or deleted a file, update the documents that link '
          'to it:\n${result.stderr}',
    );
    expect('${result.stdout}', contains('relative link(s)'));
  });
}
