// A fenced block under `<!-- test-excerpt: <path> -->` must appear verbatim in
// <path>, so a guide's sample test cannot drift from the test it quotes
// (koniz-dev/flutter-starter#432: the security guide's sample tested a
// `LogSanitizer` class that never existed).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _directive = RegExp(r'^<!-- test-excerpt: (\S+) -->$');

/// (markdown path, line, cited path, fenced body) for every directive.
List<(String, int, String, String?)> _excerpts() {
  final found = <(String, int, String, String?)>[];
  final docs = Directory('docs')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) => f.path.endsWith('.md') && !f.path.contains('docs/verification/'),
      );
  for (final file in docs) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final m = _directive.firstMatch(lines[i].trim());
      if (m == null) continue;
      String? body;
      if (i + 1 < lines.length && lines[i + 1].startsWith('```')) {
        final end = lines.indexWhere((l) => l.startsWith('```'), i + 2);
        if (end > 0) body = lines.sublist(i + 2, end).join('\n');
      }
      found.add((file.path, i + 1, m.group(1)!, body));
    }
  }
  return found;
}

void main() {
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
