// `check_docs --links` scans the markdown outside `docs/` too, and fails on a
// link that leaves the repository (test/README.md once had four `../../`
// links and nothing failed).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository's package config: `dart <file>` with it skips `dart run`'s
/// build-hook step, whose native-asset bundling crashed when several tests
/// ran it at once.
final String _packages = File(
  '.dart_tool/package_config.json',
).absolute.path;

void main() {
  final checker = File('tool/check_docs.dart').absolute.path;
  late Directory sandbox;
  late Directory repo;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('check_docs_links_');
    repo = Directory('${sandbox.path}/repo')..createSync();
    Directory('${repo.path}/docs').createSync();
    File('${repo.path}/docs/index.md').writeAsStringSync('# Index\n');
    // Exists, but outside the checkout: only the escape rule can catch it.
    File('${sandbox.path}/outside.md').writeAsStringSync('# Outside\n');
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  void write(String path, String body) {
    File('${repo.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(body);
  }

  ProcessResult links() => Process.runSync('dart', [
    '--packages=$_packages',
    checker,
    '--links',
  ], workingDirectory: repo.path);

  test('criterion 2: a test/README.md link escaping the repo fails', () {
    write('test/README.md', '[out](../../outside.md)\n');

    final result = links();

    expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
    expect(
      result.stderr,
      contains('test/README.md:1: escapes the repository -> ../../outside.md'),
    );
  });

  test('criterion 2: the fixed link inside the repo passes', () {
    write('test/README.md', '[docs](../docs/index.md)\n');

    final result = links();

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('in 2 file(s); 0 broken'));
  });

  test('criterion 1: root files and every listed directory are scanned', () {
    const scanned = [
      'README.md',
      'CONTRIBUTING.md',
      'CHANGELOG.md',
      'CLAUDE.md',
      'test/a/x.md',
      'scripts/x.md',
      'tool/x.md',
      'bricks/b/x.md',
      'examples/x.md',
      'integration_test/x.md',
      'fastlane/x.md',
    ];
    for (final path in scanned) {
      write(path, '[gone](missing.md)\n');
    }
    // Not in scope: lib/ markdown is not documentation for this rule.
    write('lib/x.md', '[gone](missing.md)\n');

    final result = links();

    expect(result.exitCode, 1);
    for (final path in scanned) {
      expect(
        result.stderr,
        contains('$path:1: missing path -> missing.md'),
        reason: path,
      );
    }
    expect(result.stderr, isNot(contains('lib/x.md')));
  });

  // "The repository itself passes" is the Docs check's job on main, not a
  // unit test's: strip-smoke's keep-samples job deletes bricks/ and
  // mason.yaml, which leaves links dangling in that tree.

  test(
    'criterion 3: the Docs check workflow triggers on every scanned file',
    () {
      final workflow = File(
        '.github/workflows/docs-check.yml',
      ).readAsStringSync();
      // `**/*.md` covers README.md, CONTRIBUTING.md, CHANGELOG.md and markdown
      // in every scanned directory, on both push and pull_request.
      expect("- '**/*.md'".allMatches(workflow), hasLength(2));
    },
  );
}
