#!/usr/bin/env dart
// Enables the commented-out `push:` / `pull_request:` triggers in
// `.github/workflows/*.yml`.
//
// Usage:
//   dart scripts/dev/setup_ci.dart              # asks first
//   dart scripts/dev/setup_ci.dart --yes        # no prompt
//   dart scripts/dev/setup_ci.dart --dry-run    # show the diff, write nothing
//   dart scripts/dev/setup_ci.dart --dir <path> # target another directory
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
// "deploy on every branch" (issue #57).
//
// So: only the top-level `on:` block is considered, only commented lines whose
// content is `push:` or `pull_request:` start a change, and the commented child
// lines under such a key are uncommented with it. Everything else - prose
// headers, trailing comments, commented steps in the job body - is left alone.

// Script uses print for CLI output
// ignore_for_file: avoid_print

import 'dart:io';

const _triggerKeys = {'push:', 'pull_request:'};

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final assumeYes = args.contains('--yes') || dryRun;

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

  exitCode = enableCi(dirPath, dryRun: dryRun);
}

/// Returns 0 on success, 1 when the directory does not exist.
int enableCi(String dirPath, {bool dryRun = false}) {
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
    final result = enableTriggers(original);

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
TriggerResult enableTriggers(String content) {
  final lines = content.split('\n');
  final enabled = <String>[];

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
    } else if (blockIndent == null || indent <= blockIndent) {
      // Not a trigger key and not nested under one: leave it commented.
      blockIndent = null;
      continue;
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
