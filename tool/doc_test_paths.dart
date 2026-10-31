// Checker for documented `flutter test <path>` commands that name no file.
//
// CONTRIBUTING told contributors to run
// `flutter test test/features/auth/domain/usecases/login_test.dart`; the file
// is `login_usecase_test.dart`, so the command failed for everyone who copied
// it, and nothing noticed.
//
// The rule: inside a fenced code block of README.md, CONTRIBUTING.md,
// CLAUDE.md or `docs/`, every path argument
// of `flutter test` must exist as a file or directory. Backslash-continued
// lines are joined first. Flags are skipped, with the value of a flag that
// takes one (`--tags golden`, `-r expanded`). A path with a `:<line>` suffix
// is checked without it. Placeholders are not judged: anything containing
// `<`, `>`, `$`, `*` or `{`, or the conventional `path/to`.
//
// Run by `tool/check_docs.dart`.

import 'dart:io';

/// One documented `flutter test` path that does not exist.
class MissingTestPath {
  /// Creates a problem record.
  const MissingTestPath(this.file, this.line, this.path);

  /// Path of the markdown file, relative to the repository root.
  final String file;

  /// 1-based line the command starts on.
  final int line;

  /// The path as written.
  final String path;

  @override
  String toString() =>
      '$file:$line: `flutter test $path` names no file or directory';
}

final RegExp _fence = RegExp(r'^\s*(`{3,}|~{3,})');
final RegExp _flutterTest = RegExp(r'\bflutter\s+test\b(.*)');
final RegExp _commandEnd = RegExp(r'&&|\|\||\||;|\s#');

/// `flutter test` flags whose value is the next argument.
const Set<String> _flagsWithValue = {
  '--tags',
  '-t',
  '--exclude-tags',
  '-x',
  '--plain-name',
  '--name',
  '-n',
  '--reporter',
  '-r',
  '--file-reporter',
  '--concurrency',
  '-j',
  '--coverage-path',
  '--platform',
  '-p',
  '--timeout',
  '--test-randomize-ordering-seed',
  '--dart-define',
  '--dart-define-from-file',
  '--flavor',
  '--device-id',
  '-d',
};

bool _isPlaceholder(String arg) =>
    arg.contains(RegExp(r'[<>$*{]')) || arg.contains('path/to');

/// The path arguments of one `flutter test` command line [rest] (what
/// follows `flutter test`).
List<String> testPathArguments(String rest) {
  final command = rest.split(_commandEnd).first;
  final args = command
      .split(RegExp(r'\s+'))
      .where((a) => a.isNotEmpty)
      .map((a) => a.replaceAll(RegExp('^["\']|["\']\$'), ''))
      .toList();
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('-')) {
      if (!arg.contains('=') && _flagsWithValue.contains(arg)) i++;
      continue;
    }
    if (_isPlaceholder(arg)) continue;
    paths.add(arg);
  }
  return paths;
}

/// Documented `flutter test` paths in markdown [source] that [exists] says
/// are missing, reported against [file].
List<MissingTestPath> findMissingTestPaths(
  String source,
  bool Function(String path) exists, {
  String file = '',
}) {
  final problems = <MissingTestPath>[];
  final lines = source.split('\n');
  var inFence = false;

  for (var i = 0; i < lines.length; i++) {
    if (_fence.hasMatch(lines[i])) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) continue;

    // Join a backslash-continued command onto one line.
    final start = i;
    var line = lines[i];
    while (line.trimRight().endsWith(r'\') && i + 1 < lines.length) {
      final trimmed = line.trimRight();
      line = '${trimmed.substring(0, trimmed.length - 1)} ${lines[++i]}';
    }

    for (final match in _flutterTest.allMatches(line)) {
      for (final path in testPathArguments(match.group(1)!)) {
        if (!exists(path.split(':').first)) {
          problems.add(MissingTestPath(file, start + 1, path));
        }
      }
    }
  }
  return problems;
}

/// Markdown files the rule covers: README.md, CONTRIBUTING.md, CLAUDE.md
/// and `docs/`.
List<File> testPathFiles(Directory root) {
  final files = <File>[
    for (final name in const ['README.md', 'CONTRIBUTING.md', 'CLAUDE.md'])
      if (File('${root.path}/$name').existsSync()) File('${root.path}/$name'),
  ];
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
int checkTestPaths(Directory root) {
  bool exists(String path) =>
      File('${root.path}/$path').existsSync() ||
      Directory('${root.path}/$path').existsSync();

  final files = testPathFiles(root);
  final problems = <MissingTestPath>[
    for (final file in files)
      ...findMissingTestPaths(
        file.readAsStringSync(),
        exists,
        file: file.path.substring(root.path.length + 1),
      ),
  ]..forEach(stderr.writeln);
  stdout.writeln(
    'test paths: scanned ${files.length} file(s); ${problems.length} missing',
  );
  return problems.length;
}
