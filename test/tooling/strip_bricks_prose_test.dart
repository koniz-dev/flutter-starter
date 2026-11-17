// After `--remove-bricks`, kept markdown still told the reader to run
// `mason make feature_clean` (CLAUDE.md, adding-features.md,
// troubleshooting.md): `strip:bricks` only covered passages linking into
// bricks/. Every such instruction outside bricks/ now sits in a
// `strip:bricks` region or on a marked line, so the strip removes it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every `mason make feature_clean` outside bricks/ is strip-marked', () {
    final files = Process.runSync('git', ['ls-files', '*.md']).stdout as String;
    final unmarked = <String>[];
    for (final path in files.split('\n')) {
      if (path.isEmpty || path.startsWith('bricks/')) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      var inBlock = false;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('<!-- strip:bricks start -->')) inBlock = true;
        if (line.contains('<!-- strip:bricks end -->')) inBlock = false;
        if (line.contains('mason make feature_clean') &&
            !inBlock &&
            !line.contains('<!-- strip:bricks line -->')) {
          unmarked.add('$path:${i + 1}');
        }
      }
    }

    expect(unmarked, isEmpty);
  });
}
