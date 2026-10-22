// The testing guides' test-tree listings must match the real test/ tree.
//
// Both described a test/integration/ directory that does not exist, put
// integration_test/ inside test/ (it is at the repository root), and left out
// acceptance/, docs/ and tooling/.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The top-level entries of the first ```test/``` tree in [markdown]: lines
/// starting directly with a branch, not nested under `│`.
Set<String> _topLevel(String markdown) {
  final block = RegExp(
    r'```\ntest/\n(.*?)```',
    dotAll: true,
  ).firstMatch(markdown);
  if (block == null) return const {};
  return {
    for (final m in RegExp(
      r'^[├└]── ([\w-]+)/',
      multiLine: true,
    ).allMatches(block.group(1)!))
      m.group(1)!,
  };
}

void main() {
  final actual = {
    for (final d in Directory('test').listSync().whereType<Directory>())
      d.uri.pathSegments.where((s) => s.isNotEmpty).last,
  }..removeWhere((name) => name.startsWith('.') || name.startsWith('_'));

  for (final path in const [
    'docs/guides/testing/testing-summary.md',
    'docs/guides/testing/guide.md',
  ]) {
    test(
      'criteria 1-2: $path lists exactly the top-level test/ directories',
      () {
        final markdown = File(path).readAsStringSync();

        expect(_topLevel(markdown), actual);
        expect(
          markdown,
          isNot(contains('test/integration/')),
          reason: 'there is no test/integration/ directory',
        );
      },
    );
  }
}
