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
  final package = currentPackageName();
  final dir = Directory('test/docs/_${name}_snippets')..createSync();
  try {
    for (var i = 0; i < blocks.length; i++) {
      File(
        '${dir.path}/snippet_$i.dart',
      ).writeAsStringSync(forPackage(blocks[i], package));
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

/// The template's own package name, spelled so that neither rename path
/// (`mason make flutter_starter_setup`, fork-and-customize Option B) rewrites
/// it: both replace every literal `package:flutter_starter/` in `.dart` files,
/// which would turn the rewrite below into a no-op in exactly the forks it is
/// for.
const String templatePackage =
    'flutter'
    '_starter';

/// The `name:` in `pubspec.yaml`.
String currentPackageName() => RegExp(
  r'^name:\s*(\S+)',
  multiLine: true,
).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

/// [block] with `package:<template name>/` imports pointed at [package].
///
/// The docs keep the template's package name - neither rename path rewrites
/// Markdown, and fork-and-customize makes updating it optional - so in a
/// renamed fork every snippet would otherwise import a package that no longer
/// exists and turn `flutter test` red.
String forPackage(String block, String package) =>
    block.replaceAll('package:$templatePackage/', 'package:$package/');
