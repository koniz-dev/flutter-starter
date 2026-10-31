#!/usr/bin/env dart

// Enables the commented-out `push:` / `pull_request:` triggers in
// `.github/workflows/*.yml`.
//
// Usage:
//   dart scripts/dev/setup_ci.dart              # asks first
//   dart scripts/dev/setup_ci.dart --yes        # no prompt
//   dart scripts/dev/setup_ci.dart --dry-run    # show the diff, write nothing
//   dart scripts/dev/setup_ci.dart --dir <path> # target another directory
//   dart scripts/dev/setup_ci.dart --deploy-trigger=tags    # deploy-* on tags
//   dart scripts/dev/setup_ci.dart --deploy-trigger=branch  # deploy-* on main
//
// The deploy workflows document tag-push and main-branch-push deploys as
// ALTERNATIVES, but their commented `push:` block lists both. Uncommenting the
// whole block enabled both at once, so every push to main deployed, as
// production. Without --deploy-trigger the
// deploy-* workflows are left manual-only; with it, exactly the chosen option
// is enabled and the other stays commented.
//
// Why this is line-based and block-scoped rather than a whole-file regex:
//
// The first version ran `content.replaceAll(RegExp(r'#\s*push:'), 'push:')`
// over the entire file. Every workflow here opens with a prose header that
// *documents* the trigger options, e.g.
//
//     # Option 1: Deploy on version tags
//     #   push:
//     #     tags:
//     #       - 'v*.*.*'
//
// so the unanchored pattern rewrote that explanation into a bare `push:` at
// column 0 - a second top-level workflow key - and GitHub rejected the file.
// It also only ever uncommented the key, never the `tags:`/`branches:` lines
// under it, turning the one real trigger it did touch into a null value:
// "deploy on every branch".
//
// So: only the top-level `on:` block is considered, only commented lines whose
// content is `push:` or `pull_request:` start a change, and the commented child
// lines under such a key are uncommented with it. Everything else - prose
// headers, trailing comments, commented steps in the job body - is left alone.

// Script uses print for CLI output
// ignore_for_file: avoid_print

import 'dart:io';

const _triggerKeys = {'push:', 'pull_request:'};

/// Which of the deploy workflows' documented push options to enable.
enum DeployTrigger {
  /// Deploy when a version tag is pushed (`push: tags:`).
  tags,

  /// Deploy on every push to main (`push: branches:`).
  branch,
}

const String _usage = '''
Usage: dart run scripts/dev/setup_ci.dart [options]

  --dry-run                 Show what would change; write nothing.
  --yes                     Do not ask for confirmation.
  --dir <path>              Workflows directory (default: .github/workflows).
  --deploy-trigger=<tags|branch>
                            Also enable that push trigger on the deploy
                            workflows.
  -h, --help                Print this message.''';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    print(_usage);
    return;
  }
  // An unknown flag used to be ignored, so a typo such as --dryrun wrote the
  // workflows it was meant to only preview.
  final unknown = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dir') {
      // A --dir with no value fell back to .github/workflows and wrote the
      // real workflows.
      if (i + 1 >= args.length || args[i + 1].startsWith('-')) {
        print('Error: --dir needs a path. Nothing was written.');
        print(_usage);
        exitCode = 64;
        return;
      }
      i++; // its value
    } else if (arg != '--dry-run' &&
        arg != '--yes' &&
        !arg.startsWith('--deploy-trigger=')) {
      unknown.add(arg);
    }
  }
  if (unknown.isNotEmpty) {
    print('Error: unknown option ${unknown.join(' ')}. Nothing was written.');
    print(_usage);
    exitCode = 64;
    return;
  }

  final dryRun = args.contains('--dry-run');
  final assumeYes = args.contains('--yes') || dryRun;

  DeployTrigger? deployTrigger;
  for (final arg in args.where((a) => a.startsWith('--deploy-trigger='))) {
    final value = arg.substring('--deploy-trigger='.length);
    deployTrigger = DeployTrigger.values
        .where((t) => t.name == value)
        .firstOrNull;
    if (deployTrigger == null) {
      print(
        'Error: --deploy-trigger must be "tags" or "branch", got "$value".',
      );
      exitCode = 64;
      return;
    }
  }

  var dirPath = '.github/workflows';
  final dirFlag = args.indexOf('--dir');
  if (dirFlag != -1 && dirFlag + 1 < args.length) {
    dirPath = args[dirFlag + 1];
  }

  if (!assumeYes) {
    print('--- GitHub Actions Configuration ---');
    print(
      'Do you want to enable automatic CI/CD triggers on push/pull_request? '
      '(y/N)',
    );
    final input = stdin.readLineSync()?.trim().toLowerCase();
    if (input != 'y' && input != 'yes') {
      print('Setup cancelled. CI defaults to manual dispatch.');
      return;
    }
  }

  exitCode = enableCi(dirPath, dryRun: dryRun, deployTrigger: deployTrigger);
}

/// Returns 0 on success, 1 when the directory does not exist.
///
/// `deploy-*` workflows get only [deployTrigger]'s push option, or no push
/// trigger at all when it is null.
int enableCi(
  String dirPath, {
  bool dryRun = false,
  DeployTrigger? deployTrigger,
}) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    print('Error: $dirPath not found. Run this script from the project root.');
    return 1;
  }

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final changed = <String>[];
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final original = file.readAsStringSync();
    final isDeploy = name.startsWith('deploy-');
    if (isDeploy && deployTrigger == null) {
      print(
        '  deploy workflow left manual-only: $name '
        '(pass --deploy-trigger=tags or --deploy-trigger=branch)',
      );
      continue;
    }
    final result = enableTriggers(
      original,
      deployTrigger: isDeploy ? deployTrigger : null,
    );

    if (result.enabled.isEmpty) {
      print('  no commented triggers in `on:`, unchanged: $name');
      continue;
    }

    changed.add(name);
    print('  ${dryRun ? "would enable" : "enabled"} in $name:');
    for (final line in result.enabled) {
      print('    $line');
    }
    if (!dryRun) {
      file.writeAsStringSync(result.content);
    }
  }

  print('');
  if (changed.isEmpty) {
    print('Nothing to do: no workflow had a commented trigger in its `on:`.');
    return 0;
  }
  final deploys = changed.where((f) => f.startsWith('deploy-')).toList();
  if (deploys.isNotEmpty) {
    print(
      'Note: ${deploys.join(", ")} now run automatically. Confirm the '
      'required secrets exist before pushing.',
    );
  }
  print(
    dryRun
        ? 'Dry run: nothing written.'
        : 'Done! Commit these changes to activate CI/CD.',
  );
  return 0;
}

/// The rewritten file plus the lines that were uncommented.
class TriggerResult {
  /// Creates a result.
  const TriggerResult(this.content, this.enabled);

  /// Full file content after the rewrite.
  final String content;

  /// Uncommented lines, trimmed, in file order. Empty means "no change".
  final List<String> enabled;
}

/// Uncomments `push:` / `pull_request:` blocks inside the top-level `on:` key.
///
/// With [deployTrigger], only that option's sub-block under `push:` is
/// uncommented: `tags:` (and its list) for [DeployTrigger.tags], `branches:`
/// for [DeployTrigger.branch]. The other option stays commented.
TriggerResult enableTriggers(String content, {DeployTrigger? deployTrigger}) {
  final lines = content.split('\n');
  final enabled = <String>[];
  // Indent of a `tags:` / `branches:` child that belongs to the option NOT
  // chosen; it and everything nested under it stay commented.
  int? skipIndent;

  final start = _onBlockStart(lines);
  if (start == -1) {
    return TriggerResult(content, enabled);
  }
  final end = _onBlockEnd(lines, start);

  // Indent of the commented key currently being uncommented, or null.
  int? blockIndent;

  for (var i = start + 1; i < end; i++) {
    final line = lines[i];
    final uncommented = _uncomment(line);
    if (uncommented == null) {
      // A live (non-commented) line ends any block in progress.
      if (line.trim().isNotEmpty) blockIndent = null;
      continue;
    }

    final indent = _indentOf(uncommented);
    final body = uncommented.trim();
    final isTrigger = _triggerKeys.any(
      (k) => body == k || body.startsWith('$k '),
    );

    if (isTrigger) {
      blockIndent = indent;
      skipIndent = null;
    } else if (blockIndent == null || indent <= blockIndent) {
      // Not a trigger key and not nested under one: leave it commented.
      blockIndent = null;
      continue;
    } else if (deployTrigger != null) {
      if (skipIndent != null && indent > skipIndent) continue;
      skipIndent = null;
      final option = body.startsWith('tags:')
          ? DeployTrigger.tags
          : body.startsWith('branches:')
          ? DeployTrigger.branch
          : null;
      if (option != null && option != deployTrigger) {
        skipIndent = indent;
        continue;
      }
    }

    lines[i] = uncommented;
    enabled.add(uncommented.trim());
  }

  return TriggerResult(lines.join('\n'), enabled);
}

/// Index of the top-level `on:` line, or -1.
int _onBlockStart(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    if (RegExp(r'^on:\s*(#.*)?$').hasMatch(lines[i])) return i;
  }
  return -1;
}

/// Index of the first line after the `on:` block.
int _onBlockEnd(List<String> lines, int start) {
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    // Any line whose first character is not whitespace closes the block -
    // including a column-0 comment, which is prose, not part of the mapping.
    if (!line.startsWith(' ') && !line.startsWith('\t')) return i;
  }
  return lines.length;
}

/// Strips the leading `#` (and one following space) from a commented line,
/// preserving indentation so nesting survives. Returns null when the line is
/// not a whole-line comment.
String? _uncomment(String line) {
  final match = RegExp(r'^([ \t]*)#( ?)(.*)$').firstMatch(line);
  if (match == null) return null;
  final rest = match.group(3)!;
  if (rest.trim().isEmpty) return null;
  // Drop the "# Uncomment to ..." instruction now that it has been followed.
  final cleaned = rest.replaceFirst(RegExp(r'\s+#\s*Uncomment\b.*$'), '');
  return '${match.group(1)}$cleaned';
}

int _indentOf(String line) => line.length - line.trimLeft().length;
