// CLAUDE.md's "Which checks a PR gets" table must match the workflows.
//
// Sessions read that table to decide which checks to wait for before merging,
// and nothing gates a merge on this repository. It drifted three ways: the
// Docs check row missed trigger paths, a fifth PR workflow (build.yml's JDK 25
// job) had no row, and the Strip count stayed at x3 after a fourth variant.
// These tests read the workflows' real
// `pull_request` triggers and fail on any disagreement.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The lines of [workflow]'s top-level `on:` block, comments removed.
List<String> _onBlock(List<String> workflow) {
  final start = workflow.indexWhere((l) => l.trimRight() == 'on:');
  if (start < 0) return const [];
  final block = <String>[];
  for (final line in workflow.skip(start + 1)) {
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      break;
    }
    final code = line.split('#').first.trimRight();
    if (code.trim().isNotEmpty) block.add(code);
  }
  return block;
}

/// Whether [workflow] runs on pull requests.
bool _runsOnPullRequests(List<String> workflow) =>
    _onBlock(workflow).any((l) => l.trim() == 'pull_request:');

/// The `paths:` filter under `pull_request:`, or empty when unfiltered.
List<String> _pullRequestPaths(List<String> workflow) {
  final on = _onBlock(workflow);
  final pr = on.indexWhere((l) => l.trim() == 'pull_request:');
  final paths = <String>[];
  var inPaths = false;
  for (final line in on.skip(pr + 1)) {
    final indent = line.length - line.trimLeft().length;
    if (indent <= 2) break;
    if (line.trim() == 'paths:') {
      inPaths = true;
      continue;
    }
    if (inPaths && line.trim().startsWith('- ')) {
      paths.add(line.trim().substring(2).replaceAll("'", '').trim());
    } else if (inPaths) {
      inPaths = false;
    }
  }
  return paths;
}

void main() {
  final workflows = {
    for (final f
        in Directory('.github/workflows').listSync().whereType<File>().where(
          (f) => f.path.endsWith('.yml'),
        ))
      f.uri.pathSegments.last: f.readAsLinesSync(),
  };
  final prWorkflows = {
    for (final MapEntry(key: name, value: lines) in workflows.entries)
      if (_runsOnPullRequests(lines)) name,
  };

  final claude = File('CLAUDE.md').readAsStringSync();
  final start = claude.indexOf('### Which checks a PR gets');
  final skip = start < 0
      ? 'CLAUDE.md has no "Which checks a PR gets" section'
      : null;
  // The section runs to the next heading of any level.
  final end = start < 0 ? -1 : claude.indexOf(RegExp(r'\n#{2,3} '), start + 4);
  final section = start < 0
      ? ''
      : claude.substring(start, end < 0 ? claude.length : end);
  final rows = {
    for (final m in RegExp(
      r'^\| \[`([\w.-]+\.yml)`\]\(\.github/workflows/[\w.-]+\.yml\) \|(.*)$',
      multiLine: true,
    ).allMatches(section))
      m.group(1)!: m.group(2)!,
  };

  test('the trigger parser sees the workflows it should', skip: skip, () {
    // Guards the parsing: coverage.yml mentions pull_request only in
    // comments, and ci.yml runs on every PR.
    expect(prWorkflows, contains('ci.yml'));
    expect(prWorkflows, isNot(contains('coverage.yml')));
    expect(_pullRequestPaths(workflows['ci.yml']!), isEmpty);
  });

  test(
    'criterion 3: the table has one row per PR-triggered workflow',
    skip: skip,
    () {
      expect(rows.keys.toSet(), prWorkflows);
    },
  );

  test(
    'criteria 1-2: each filtered row names every trigger path',
    skip: skip,
    () {
      final missing = <String>[
        for (final name in prWorkflows)
          for (final path in _pullRequestPaths(workflows[name]!))
            if (!(rows[name] ?? '').contains('`$path`')) '$name: $path',
      ];
      expect(missing, isEmpty, reason: 'CLAUDE.md rows omit: $missing');
    },
  );

  test(
    'the Strip row counts the strip-smoke variants',
    skip:
        skip ??
        (workflows.containsKey('strip-smoke.yml')
            ? null
            : 'no strip-smoke.yml: the sample strip has removed itself'),
    () {
      final variants = workflows['strip-smoke.yml']!
          .where((l) => l.trim().startsWith('- variant:'))
          .length;
      expect(rows['strip-smoke.yml'], contains('(x$variants)'));
    },
  );
}
