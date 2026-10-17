// Shared by the test/docs snippet-compile tests: extract a document's
// self-contained ```dart blocks and analyze them against this repository.

import 'dart:convert';
import 'dart:io';

/// The fenced `dart` blocks of [markdown] whose first line is an import.
List<String> importingDartBlocks(String markdown) {
  final fence = RegExp(
    r'^```dart\s*\n(.*?)^```',
    multiLine: true,
    dotAll: true,
  );
  return [
    for (final match in fence.allMatches(markdown))
      if (match.group(1)!.trimLeft().startsWith('import ')) match.group(1)!,
  ];
}

/// The ERROR and WARNING lines `dart analyze` reports for [blocks].
///
/// The blocks are written to `test/docs/_<name>_snippets/`, inside the
/// project so `package:` imports resolve, and two levels below `test/` so a
/// relative `../../helpers/...` import reaches `test/helpers/`. The
/// directory is deleted afterwards.
List<String> analyzeSnippets(String name, List<String> blocks) {
  final dir = Directory('test/docs/_${name}_snippets')..createSync();
  try {
    for (var i = 0; i < blocks.length; i++) {
      File('${dir.path}/snippet_$i.dart').writeAsStringSync(blocks[i]);
    }
    final result = Process.runSync('dart', [
      'analyze',
      '--format=machine',
      dir.path,
    ]);
    return const LineSplitter()
        .convert('${result.stdout}${result.stderr}')
        .where((l) => l.startsWith('ERROR|') || l.startsWith('WARNING|'))
        .toList();
  } finally {
    dir.deleteSync(recursive: true);
  }
}
