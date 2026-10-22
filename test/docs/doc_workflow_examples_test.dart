// GitHub Actions examples in the docs must run on this repository's tooling.
//
// The security guide's CI example pinned `flutter-version: '3.24.0'`, whose
// Dart SDK is below pubspec.yaml's `sdk:` constraint so `pub get` failed, and
// used `actions/upload-artifact@v3`, which GitHub has retired. This compares
// every `uses: owner/action@vN` in a fenced block of README.md,
// CONTRIBUTING.md or docs/ with the major .github/workflows/ uses for the same
// action, and rejects a `flutter-version:` pin: the workflows float the
// stable channel, which always satisfies the SDK constraint.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _uses = RegExp(r'uses:\s*([\w.-]+/[\w.-]+)@(v\d+)');
final RegExp _fence = RegExp(r'^\s*(`{3,}|~{3,})');

List<File> _docs() => [
  for (final name in const ['README.md', 'CONTRIBUTING.md'])
    if (File(name).existsSync()) File(name),
  ...Directory('docs')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.md')),
];

/// `(line, text)` of every line inside a fenced block of [source].
Iterable<(int, String)> _fencedLines(String source) sync* {
  var inFence = false;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (_fence.hasMatch(lines[i])) {
      inFence = !inFence;
      continue;
    }
    if (inFence) yield (i + 1, lines[i]);
  }
}

void main() {
  final workflowMajors = <String, Set<String>>{};
  for (final f in Directory('.github/workflows').listSync().whereType<File>()) {
    for (final m in _uses.allMatches(f.readAsStringSync())) {
      (workflowMajors[m.group(1)!] ??= {}).add(m.group(2)!);
    }
  }

  test('criterion 1: documented actions use the majors the workflows use', () {
    expect(workflowMajors, isNotEmpty);
    final problems = <String>[];
    for (final doc in _docs()) {
      for (final (line, text) in _fencedLines(doc.readAsStringSync())) {
        for (final m in _uses.allMatches(text)) {
          final used = workflowMajors[m.group(1)!];
          if (used != null && !used.contains(m.group(2))) {
            problems.add(
              '${doc.path}:$line: ${m.group(1)}@${m.group(2)}, workflows use '
              '${used.join(', ')}',
            );
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('criterion 1: no documented workflow pins flutter-version', () {
    final pins = [
      for (final doc in _docs())
        for (final (line, text) in _fencedLines(doc.readAsStringSync()))
          if (text.contains(RegExp(r'^\s*flutter-version:')))
            '${doc.path}:$line: ${text.trim()}',
    ];
    expect(
      pins,
      isEmpty,
      reason:
          "Use channel: 'stable', as .github/workflows/ does; a pin can fall "
          "below pubspec.yaml's sdk constraint:\n${pins.join('\n')}",
    );
  });
}
