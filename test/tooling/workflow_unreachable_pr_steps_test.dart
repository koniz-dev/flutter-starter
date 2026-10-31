// coverage.yml carried a PR-comment step gated on
// `github.event_name == 'pull_request'`, in a workflow with no
// `pull_request` trigger: it could never run, and it kept the job's
// `pull-requests: write` scope for nothing. A step that checks for an event
// its workflow never receives is dead code.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The events in a workflow's top-level `on:` block, comments ignored.
Set<String> _triggers(String workflow) {
  final lines = workflow.split('\n');
  final start = lines.indexWhere((l) => RegExp(r'^on:\s*$').hasMatch(l));
  if (start == -1) return {};
  return {
    for (final line
        in lines
            .skip(start + 1)
            .takeWhile(
              (l) => l.isEmpty || l.startsWith(' ') || l.startsWith('#'),
            ))
      if (RegExp('^  ([a-z_]+):').firstMatch(line) case final m?) m.group(1)!,
  };
}

void main() {
  final workflows = Directory('.github/workflows')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yml'))
      .toList();

  test('the trigger reader sees the triggers', () {
    expect(
      _triggers(File('.github/workflows/ci.yml').readAsStringSync()),
      contains('pull_request'),
    );
    expect(
      _triggers(File('.github/workflows/coverage.yml').readAsStringSync()),
      {'workflow_dispatch', 'schedule'},
    );
    expect(
      _triggers('on:\n  # pull_request:\n  push:\n    branches: [main]\n'),
      {'push'},
    );
  });

  for (final workflow in workflows) {
    final name = workflow.uri.pathSegments.last;
    final text = workflow.readAsStringSync();

    test('$name gates no step on a pull_request event it never gets', () {
      final checked = RegExp(
        r'''^[^#\n]*github\.event_name\s*==\s*'(pull_request(?:_target)?)'.*$''',
        multiLine: true,
      ).allMatches(text);
      final triggers = _triggers(text);
      for (final check in checked) {
        expect(
          triggers,
          contains(check.group(1)),
          reason: '$name never runs on ${check.group(1)}: ${check.group(0)}',
        );
      }
    });
  }

  test('coverage.yml asks for no pull-requests scope', () {
    final text = File('.github/workflows/coverage.yml').readAsStringSync();
    expect(
      text,
      isNot(contains(RegExp(r'^[^#\n]*pull-requests:', multiLine: true))),
    );
  });
}
