// No guide may tell an adopter to put feature providers in core DI.
//
// Feature DI lives in `lib/features/<feature>/di/<feature>_providers.dart` -
// what `create_feature.sh` and the `feature_clean` brick generate - and #221
// removed feature names from `lib/core`. Five guides still said "add to
// `lib/core/di/providers.dart`" (or "remove from" it), which, followed
// literally, adds a `core -> features` import that
// `test/tooling/import_rules_test.dart` rejects
// (koniz-dev/flutter-starter#356).
//
// The check is textual: a line that pairs an instruction verb with
// `core/di/providers.dart` is flagged unless the same line negates it
// ("never", "not", "no feature providers"), which is how the corrected guides
// mention the file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _instruction = RegExp(
  r'\b(add|remove|update|put|register|define)\w*\b[^.]*core/di/providers\.dart',
  caseSensitive: false,
);
final RegExp _negated = RegExp(
  r'\bnever\b|\bnot\b|no feature providers',
  caseSensitive: false,
);

/// Lines in [source] that instruct putting providers in core DI.
List<int> coreDiInstructionLines(String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (_instruction.hasMatch(lines[i]) && !_negated.hasMatch(lines[i]))
        i + 1,
  ];
}

void main() {
  group('coreDiInstructionLines', () {
    test('flags each instruction form the guides used before #356', () {
      for (final line in const [
        'Add providers to `lib/core/di/providers.dart`.',
        'Add to `lib/core/di/providers.dart`:',
        '# Remove related providers from lib/core/di/providers.dart',
        '**Update `lib/core/di/providers.dart`:**',
        '2. Check provider is defined in `lib/core/di/providers.dart`',
        '- Remove auth, related providers in `lib/core/di/providers.dart`.',
      ]) {
        expect(coreDiInstructionLines(line), [1], reason: line);
      }
    });

    test('allows a line that says not to', () {
      expect(
        coreDiInstructionLines(
          'Add providers to `lib/features/x/di/x_providers.dart` (never '
          '`lib/core/di/providers.dart`).',
        ),
        isEmpty,
      );
    });
  });

  test('no document tells adopters to put feature providers in core DI', () {
    final root = Directory.current.path;
    final files = <File>[
      File('$root/README.md'),
      File('$root/CONTRIBUTING.md'),
      ...Directory('$root/docs')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md')),
    ].where((f) => f.existsSync());

    final offenders = <String>[
      for (final file in files)
        for (final line in coreDiInstructionLines(file.readAsStringSync()))
          '${file.path.substring(root.length + 1)}:$line',
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'Feature providers belong in lib/features/<feature>/di/; '
          'lib/core/di/providers.dart must not import features.',
    );
  });
}
