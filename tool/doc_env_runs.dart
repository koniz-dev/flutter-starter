// Checker for setup instructions that copy `.env` and then ignore it.
//
// `.env` is deliberately not a Flutter asset, so it reaches the app only
// through `--dart-define-from-file=.env`. README's Quick Start and
// CONTRIBUTING told a newcomer to `cp .env.example .env`, fill it in, and then
// run plain `flutter run` - which silently ran on the built-in defaults.
//
// The rule: in a fenced code block, the first `flutter run` or `flutter build`
// command after a `cp .env.example .env` line must pass
// `--dart-define-from-file`, or `--dart-define=` for a reader deliberately
// choosing explicit flags instead. Only that first command is checked - it is
// the step the instructions present as "now run it". A line ending in `\` is
// joined with its continuation, so a multi-line command counts as one.
//
// Run by `tool/check_docs.dart` over README.md, CONTRIBUTING.md and `docs/`.

import 'dart:io';

/// One setup sequence that copies `.env` and then runs without it.
class EnvRunProblem {
  /// Creates a problem record.
  const EnvRunProblem(this.file, this.line, this.command);

  /// Path of the markdown file, relative to the repository root.
  final String file;

  /// 1-based line of the offending command.
  final int line;

  /// The command as written, continuations joined.
  final String command;

  @override
  String toString() =>
      '$file:$line: `$command` follows `cp .env.example .env` without '
      '--dart-define-from-file=.env, so the copied .env is never read';
}

final RegExp _copyEnv = RegExp(r'\bcp\s+\.env\.example\s+\.env\b');
final RegExp _flutterRunOrBuild = RegExp(r'\bflutter\s+(?:run|build)\b');
final RegExp _fence = RegExp(r'^\s*(`{3,}|~{3,})');

/// Problems in one markdown [source], reported against [file].
List<EnvRunProblem> findEnvRunProblems(String source, {String file = ''}) {
  final problems = <EnvRunProblem>[];
  final lines = source.split('\n');
  var inFence = false;
  var awaitingRun = false;

  for (var i = 0; i < lines.length; i++) {
    if (_fence.hasMatch(lines[i])) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) continue;

    final start = i;
    var command = lines[i].trimRight();
    while (command.endsWith(r'\') && i + 1 < lines.length) {
      i++;
      command =
          '${command.substring(0, command.length - 1).trimRight()} '
          '${lines[i].trim()}';
    }
    final code = command.split('#').first;

    if (_copyEnv.hasMatch(code)) {
      awaitingRun = true;
      continue;
    }
    if (awaitingRun && _flutterRunOrBuild.hasMatch(code)) {
      awaitingRun = false;
      if (!code.contains('--dart-define-from-file') &&
          !code.contains('--dart-define=')) {
        problems.add(EnvRunProblem(file, start + 1, code.trim()));
      }
    }
  }
  return problems;
}

/// Markdown files the rule covers: README.md, CONTRIBUTING.md and `docs/`.
List<File> envRunFiles(Directory root) {
  final files = <File>[
    for (final name in ['README.md', 'CONTRIBUTING.md'])
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
int checkEnvRuns(Directory root) {
  final files = envRunFiles(root);
  final problems = <EnvRunProblem>[
    for (final file in files)
      ...findEnvRunProblems(
        file.readAsStringSync(),
        file: file.path.substring(root.path.length + 1),
      ),
  ]..forEach(stderr.writeln);
  stdout.writeln(
    'env runs: scanned ${files.length} file(s); '
    '${problems.length} run(s) ignoring the copied .env',
  );
  return problems.length;
}
