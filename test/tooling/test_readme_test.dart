// test/README.md must point inside the repository and describe the real
// test/ tree.
//
// Four of its links used `../../` from test/, which resolves outside the
// repository, and its tree listed a test/integration/ directory that does
// not exist while leaving out acceptance/, docs/ and tooling/. check_docs
// does not walk test/, so this pins test/README.md itself.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final readme = File('test/README.md').readAsStringSync();
  final root = Directory.current.absolute.path;

  test('criterion 1: every relative link resolves to a file in the repo', () {
    final links = RegExp(r'\]\(([^)#\s]+)(?:#[^)]*)?\)')
        .allMatches(readme)
        .map((m) => m.group(1)!)
        .where((l) => !l.contains('://') && !l.startsWith('mailto:'))
        .toList();
    expect(links, isNotEmpty);

    final problems = <String>[];
    for (final link in links) {
      final target = File('test/$link').absolute;
      final normalized = target.uri.normalizePath().toFilePath();
      if (!normalized.startsWith('$root/')) {
        problems.add('$link resolves outside the repository');
      } else if (!File(normalized).existsSync() &&
          !Directory(normalized).existsSync()) {
        problems.add('$link does not exist');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('criterion 2: the tree listing is exactly the top-level test/ '
      'directories', () {
    final block = RegExp(
      r'```\ntest/\n(.*?)```',
      dotAll: true,
    ).firstMatch(readme);
    expect(block, isNotNull, reason: 'the README shows a test/ tree');
    final listed = {
      for (final m in RegExp(r'[├└]── ([\w-]+)/').allMatches(block!.group(1)!))
        m.group(1)!,
    };
    final actual = {
      for (final d in Directory('test').listSync().whereType<Directory>())
        d.uri.pathSegments.where((s) => s.isNotEmpty).last,
    }..removeWhere((name) => name.startsWith('.') || name.startsWith('_'));

    expect(listed, actual);
  });
}
