// A fenced block under `<!-- test-excerpt: <path> -->` must appear verbatim in
// <path>, so a guide's sample test cannot drift from the test it quotes
// (the security guide's sample once tested a `LogSanitizer` class that never
// existed).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_fences.dart';

final RegExp _directive = RegExp(r'^<!-- test-excerpt: (\S+) -->$');

/// The body of the fenced block that opens on the line after [directive], or
/// null when none does or it never closes.
///
/// The block ends at its own closing fence: a shorter fence inside a
/// four-backtick block is part of the body.
String? _fencedBodyAfter(List<String> lines, int directive) {
  final fences = FenceTracker();
  final open = directive + 1;
  if (open >= lines.length || !fences.isFence(lines[open])) return null;
  for (var i = open + 1; i < lines.length; i++) {
    if (fences.isFence(lines[i])) return lines.sublist(open + 1, i).join('\n');
  }
  return null;
}

/// (markdown path, line, cited path, fenced body) for every directive.
List<(String, int, String, String?)> _excerpts() {
  final found = <(String, int, String, String?)>[];
  final docs = Directory('docs')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) => f.path.endsWith('.md'),
      );
  for (final file in docs) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final m = _directive.firstMatch(lines[i].trim());
      if (m == null) continue;
      found.add((file.path, i + 1, m.group(1)!, _fencedBodyAfter(lines, i)));
    }
  }
  return found;
}

void main() {
  test('a fence nested in a longer fence stays in the body', () {
    final lines = [
      '<!-- test-excerpt: test/x_test.dart -->',
      '````markdown',
      '```dart',
      'example();',
      '```',
      'void main() {}',
      '````',
      'prose',
    ];
    expect(
      _fencedBodyAfter(lines, 0),
      '```dart\nexample();\n```\nvoid main() {}',
    );
    expect(_fencedBodyAfter(['<!-- x -->', 'prose'], 0), isNull);
    expect(_fencedBodyAfter(['<!-- x -->', '```', 'never closed'], 0), isNull);
  });

  test('every test excerpt is verbatim from the file it cites', () {
    final excerpts = _excerpts();
    expect(excerpts, isNotEmpty, reason: 'the security guide carries one');

    for (final (doc, line, cited, body) in excerpts) {
      final where = '$doc:$line';
      expect(body, isNotNull, reason: '$where: no fenced block follows');
      final source = File(cited);
      expect(source.existsSync(), isTrue, reason: '$where: $cited is missing');
      expect(
        source.readAsStringSync(),
        contains(body),
        reason: '$where: the excerpt is not in $cited',
      );
    }
  });
}
