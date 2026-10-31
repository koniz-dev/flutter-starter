// git runs a hook from the top of the working tree. With the app in a
// subdirectory of a larger repository (a monorepo), pre-push ran
// `flutter test` there, found no test/ directory, and rejected every push.
// It now runs in the app its own file belongs to.
//
// The real hook, with a stub `flutter` on PATH that records where it ran.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('pre_push_cwd_');
    final bin = Directory('${root.path}/bin')..createSync();
    final flutter = File('${bin.path}/flutter')
      ..writeAsStringSync('#!/usr/bin/env bash\npwd -P > "\$RAN_IN"\n');
    Process.runSync('chmod', ['+x', flutter.path]);
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// Where `flutter` ran when [hook] was run from [cwd].
  String ranIn(String cwd, String hook) {
    final record = '${root.path}/ran_in';
    final result = Process.runSync(
      'bash',
      [hook],
      workingDirectory: cwd,
      environment: {
        'PATH': '${root.path}/bin:${Platform.environment['PATH']}',
        'RAN_IN': record,
      },
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    return File(record).readAsStringSync().trim();
  }

  Directory app(String path) {
    final dir = Directory(path)..createSync(recursive: true);
    File('.githooks/pre-push').copySync(
      (File(
        '${dir.path}/.githooks/pre-push',
      )..createSync(recursive: true)).path,
    );
    return dir;
  }

  test('in a monorepo, flutter test runs in the app, not the top', () {
    final top = Directory('${root.path}/mono')..createSync();
    final inner = app('${top.path}/apps/shop');

    expect(
      ranIn(top.path, 'apps/shop/.githooks/pre-push'),
      inner.resolveSymbolicLinksSync(),
    );
  });

  test('with the app at the top, it runs at the top as before', () {
    final top = app('${root.path}/plain');

    expect(
      ranIn(top.path, '.githooks/pre-push'),
      top.resolveSymbolicLinksSync(),
    );
  });

  test('a copy outside the working tree runs where git started it', () {
    final top = Directory('${root.path}/tree')..createSync();
    final shared = app('${root.path}/shared');

    expect(
      ranIn(top.path, '${shared.path}/.githooks/pre-push'),
      top.resolveSymbolicLinksSync(),
    );
  });
}
