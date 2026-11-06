// audit_template.sh compares hashes of every generated file before and after
// build_runner. It hashed with `shasum ... 2>/dev/null || true`, so on a
// machine without shasum both lists were empty and it reported the generated
// code as matching after build_runner had rewritten a stale file. It now
// falls back to sha256sum and refuses when neither exists.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A PATH holding only [tools], linked from wherever they are installed.
String _pathWith(Directory bin, List<String> tools) {
  for (final tool in tools) {
    final found = Process.runSync('bash', ['-c', 'command -v $tool']);
    final target = (found.stdout as String).trim();
    if (target.isEmpty) throw StateError('$tool is not installed');
    Link('${bin.path}/$tool').createSync(target);
  }
  return bin.path;
}

void main() {
  late Directory bin;

  setUp(() => bin = Directory.systemTemp.createTempSync('audit_hash_'));
  tearDown(() => bin.deleteSync(recursive: true));

  test('refuses before any check when no SHA-256 tool exists', () {
    final result = Process.runSync(
      '/bin/bash',
      ['scripts/dev/audit_template.sh'],
      environment: {
        'PATH': _pathWith(bin, ['dirname', 'git']),
      },
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
    expect(result.stderr, contains('Neither shasum nor sha256sum'));
    expect(
      result.stdout,
      isNot(contains('==>')),
      reason: 'nothing may run before the refusal',
    );
  });
}
