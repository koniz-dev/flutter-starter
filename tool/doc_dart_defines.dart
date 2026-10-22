// Checker for documented `--dart-define` keys the app never reads.
//
// `DartDefines.values` (lib/core/config/dart_defines.dart) is the only place a
// `--dart-define` reaches the app: a key missing from that const table cannot
// be read in a release build at all. The security guide once told readers to
// build production with `--dart-define=CERTIFICATE_FINGERPRINTS=...`, a key
// nothing reads, so a release built from it shipped unpinned.
// Nothing failed.
//
// The rule: inside a fenced code block, every `--dart-define=<KEY>=` and
// `--dart-define <KEY>=` must name a key of `DartDefines.values`. The known
// keys are parsed from the table's source rather than imported, so this runs
// under plain `dart run` with no Flutter toolchain; `test/docs/` pins the
// parsed set to the real map.
//
// Run by `tool/check_docs.dart` over README.md and `docs/`.

import 'dart:io';

/// The table every documented key is checked against.
const String dartDefinesPath = 'lib/core/config/dart_defines.dart';

/// One documented `--dart-define` key that `DartDefines.values` lacks.
class UnknownDartDefine {
  /// Creates a problem record.
  const UnknownDartDefine(this.file, this.line, this.key);

  /// Path of the markdown file, relative to the repository root.
  final String file;

  /// 1-based line of the flag.
  final int line;

  /// The key as written.
  final String key;

  @override
  String toString() =>
      '$file:$line: --dart-define key `$key` is not in DartDefines.values, '
      'so the app never reads it';
}

final RegExp _tableEntry = RegExp(
  r"""['"]([A-Za-z_][A-Za-z0-9_]*)['"]\s*:\s*String\.fromEnvironment\(""",
);
final RegExp _dartDefine = RegExp(
  r'--dart-define(?:=|\s+)([A-Za-z_][A-Za-z0-9_]*)=',
);
final RegExp _fence = RegExp(r'^\s*(`{3,}|~{3,})');

/// The keys of `DartDefines.values`, parsed from [source] of
/// [dartDefinesPath].
Set<String> parseDartDefineKeys(String source) => {
  for (final match in _tableEntry.allMatches(source)) match.group(1)!,
};

/// Documented keys in one markdown [source] that are not in [known],
/// reported against [file].
List<UnknownDartDefine> findUnknownDartDefines(
  String source,
  Set<String> known, {
  String file = '',
}) {
  final problems = <UnknownDartDefine>[];
  final lines = source.split('\n');
  var inFence = false;

  for (var i = 0; i < lines.length; i++) {
    if (_fence.hasMatch(lines[i])) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) continue;

    for (final match in _dartDefine.allMatches(lines[i])) {
      final key = match.group(1)!;
      if (!known.contains(key)) {
        problems.add(UnknownDartDefine(file, i + 1, key));
      }
    }
  }
  return problems;
}

/// Markdown files the rule covers: README.md and `docs/`.
List<File> dartDefineFiles(Directory root) {
  final readme = File('${root.path}/README.md');
  final files = <File>[if (readme.existsSync()) readme];
  final docs = Directory('${root.path}/docs');
  if (docs.existsSync()) {
    files.addAll(
      docs
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md')),
    );
  }
  return files..sort((a, b) => a.path.compareTo(b.path));
}

/// Runs the rule over [root] and prints a summary; returns the problem count.
int checkDartDefines(Directory root) {
  final table = File('${root.path}/$dartDefinesPath');
  if (!table.existsSync()) {
    stderr.writeln('$dartDefinesPath not found; run from the repository root.');
    return 1;
  }
  final known = parseDartDefineKeys(table.readAsStringSync());
  if (known.isEmpty) {
    stderr.writeln(
      '$dartDefinesPath: no `String.fromEnvironment` entries parsed; the '
      'table format changed and tool/doc_dart_defines.dart must follow it.',
    );
    return 1;
  }

  final files = dartDefineFiles(root);
  final problems = <UnknownDartDefine>[
    for (final file in files)
      ...findUnknownDartDefines(
        file.readAsStringSync(),
        known,
        file: file.path.substring(root.path.length + 1),
      ),
  ]..forEach(stderr.writeln);
  stdout.writeln(
    'dart-defines: scanned ${files.length} file(s) against ${known.length} '
    'known key(s); ${problems.length} unknown',
  );
  return problems.length;
}
