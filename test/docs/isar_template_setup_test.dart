import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `flutter pub add` commands in the numbered "Run:" steps of [text].
List<String> _setupCommands(String text) => RegExp(
  r'^\s*(?://\s*)?\d+\.\s+Run:\s+`?(flutter pub add[^`\n]*)`?\s*$',
  multiLine: true,
).allMatches(text).map((m) => m.group(1)!.trim()).toList();

void main() {
  final template = File(
    'lib/core/storage/isar_database_template.dart',
  ).readAsStringSync();
  final doc = File('docs/api/core/storage.md').readAsStringSync();

  test('the template and the storage guide give the same setup commands', () {
    expect(_setupCommands(template), isNotEmpty);
    expect(_setupCommands(doc), _setupCommands(template));
  });

  // The original isar_generator 3.x needs source_gen 1.x, which freezed 4
  // rules out, so a step that adds it fails version solving.
  test('no setup step adds the original isar packages', () {
    for (final command in _setupCommands(template)) {
      expect(
        command
            .split(RegExp(r'\s+'))
            .skip(3)
            .where((word) => !word.startsWith('-')),
        everyElement(startsWith('isar_community')),
        reason: command,
      );
    }
    expect(template, isNot(contains("// import 'package:isar/")));
    expect(template, contains("// import 'package:isar_community/isar.dart';"));
  });
}
