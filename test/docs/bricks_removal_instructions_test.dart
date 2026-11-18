import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mason removal instructions name the strip option', () {
    final paths =
        (Process.runSync('git', ['ls-files', '*.md']).stdout as String).split(
          '\n',
        );
    final missingOption = <String>[];
    for (final path in paths.where((path) => path.isNotEmpty)) {
      final file = File(path);
      if (!file.existsSync()) continue;
      for (final paragraph in file.readAsStringSync().split(
        RegExp(r'\n\s*\n'),
      )) {
        // Table rows are separate instructions, not one shared paragraph.
        final passages = paragraph.startsWith('|')
            ? paragraph.split('\n')
            : [paragraph];
        for (final passage in passages) {
          if (RegExp(r'bricks/|mason\.yaml').hasMatch(passage) &&
              RegExp(
                r'\b(remove|delete|deleting|drop)\b',
                caseSensitive: false,
              ).hasMatch(passage) &&
              !passage.contains('--remove-bricks')) {
            missingOption.add('$path: $passage');
          }
        }
      }
    }
    expect(missingOption, isEmpty);
  });

  test(
    'manual Mason deletion warns about analyzer and test imports',
    () {
      final guide = File(
        'docs/guides/onboarding/fork-and-customize.md',
      ).readAsStringSync();
      final passage = guide
          .split(RegExp(r'\n\s*\n'))
          .singleWhere(
            (paragraph) => paragraph.contains('If you never use Mason'),
          );
      expect(passage, contains('--remove-bricks'));
      expect(passage, contains('flutter analyze'));
      expect(passage, contains('flutter test'));
      expect(passage, contains('by hand'));
    },
    skip: !Directory('bricks').existsSync() ? 'Mason has been stripped' : null,
  );
}
