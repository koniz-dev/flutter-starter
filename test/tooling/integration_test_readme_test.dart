// integration_test/README.md must not cite a tool/golden/ path that does not
// exist (koniz-dev/flutter-starter#585). The README said
// "`tool/golden/no_feature_flags/` shows the wiring, and its own
// `app_e2e_test.dart` does drive the full tasks flow" - the directory exists,
// the E2E file in it was deleted in #93. So a sentence that cites a golden
// variant and names a `*_test.dart` file is read as claiming that file is in
// the variant's integration_test/, and that claim is checked too.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String _readme = File('integration_test/README.md').readAsStringSync();

void main() {
  // After a sample strip the tool removes itself, tool/golden/ included, and
  // the README's lines about it go too (koniz-dev/flutter-starter#622).
  final skip = Directory('tool/golden').existsSync()
      ? null
      : 'no tool/golden/: the sample strip has removed itself';

  test('every tool/golden/ path the README names exists', skip: skip, () {
    final cited = {
      for (final m in RegExp(r'tool/golden/[\w./-]*').allMatches(_readme))
        m.group(0)!,
    };

    expect(cited, isNotEmpty, reason: 'the README documents the strip goldens');
    final missing = [
      for (final path in cited)
        if (!File(path).existsSync() && !Directory(path).existsSync()) path,
    ];
    expect(missing, isEmpty);
  });

  test('a test file attributed to a golden variant is in that variant', () {
    final variant = RegExp(r'tool/golden/(\w+)/');
    final testFile = RegExp(r'`(?:[\w/]*/)?(\w+_test\.dart)`');
    final wrong = <String>[];
    for (final sentence in _readme.split(RegExp(r'(?<=[.!?])\s+|\n\s*\n'))) {
      final variants = variant.allMatches(sentence).map((m) => m.group(1)!);
      for (final name in variants.toSet()) {
        for (final file in testFile.allMatches(sentence)) {
          final path = 'tool/golden/$name/integration_test/${file.group(1)}';
          if (!File(path).existsSync()) wrong.add(path);
        }
      }
    }
    expect(wrong, isEmpty);
  });
}
