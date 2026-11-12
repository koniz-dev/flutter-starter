// A staging or production build made by scripts/ci/build_all.sh or the manual
// build workflow fell back to https://api.example.com when no URL was given,
// so it produced an app pointing at a placeholder host, and nothing at startup
// refuses that. scripts/ci/release_base_url.sh now resolves the URL from
// BASE_URL_STAGING / BASE_URL_PRODUCTION and refuses a missing, non-https or
// example.com one before anything is built.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sources the helper, calls it with the given arguments and environment,
/// and prints the resolved BASE_URL on success.
const String _script =
    r'. scripts/ci/release_base_url.sh; release_base_url "$@"; '
    r'printf "BASE_URL=%s" "$BASE_URL"';

Future<ProcessResult> _resolve(
  List<String> arguments, {
  Map<String, String> env = const {},
}) => Process.run(
  'bash',
  ['-euc', _script, 'bash', ...arguments],
  environment: {
    // Not inherited from the machine running the tests.
    'BASE_URL_STAGING': '',
    'BASE_URL_PRODUCTION': '',
    ...env,
  },
);

void main() {
  test('the URL comes from the variable named after the environment', () async {
    const env = {
      'BASE_URL_STAGING': 'https://api.staging.test/v1',
      'BASE_URL_PRODUCTION': 'https://api.production.test',
    };

    final staging = await _resolve(['staging'], env: env);
    final production = await _resolve(['production'], env: env);

    expect(staging.exitCode, 0, reason: '${staging.stderr}');
    expect(staging.stdout, 'BASE_URL=https://api.staging.test/v1');
    expect(production.exitCode, 0, reason: '${production.stderr}');
    expect(production.stdout, 'BASE_URL=https://api.production.test');
  });

  test('an explicit URL wins over the variable', () async {
    final result = await _resolve(
      ['staging', ' https://explicit.test '],
      env: {'BASE_URL_STAGING': 'https://api.staging.test'},
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, 'BASE_URL=https://explicit.test');
  });

  test('a missing URL is refused, naming the variable to set', () async {
    final staging = await _resolve(['staging']);
    final production = await _resolve(
      ['production', ''],
      // The other environment's URL is not borrowed.
      env: {'BASE_URL_STAGING': 'https://api.staging.test'},
    );

    expect(staging.exitCode, isNot(0));
    expect('${staging.stderr}', contains('BASE_URL_STAGING'));
    expect(staging.stdout, isEmpty);
    expect(production.exitCode, isNot(0));
    expect('${production.stderr}', contains('BASE_URL_PRODUCTION'));
  });

  test('the example.com placeholder is refused in every spelling', () async {
    for (final url in [
      'https://api.example.com',
      'https://api-staging.example.com/v1',
      'https://example.com',
      'https://API.Example.COM.',
      'https://user:pw@api.example.com:8443/v1',
      'HTTPS://api.example.com?x=1',
    ]) {
      final result = await _resolve(['production', url]);

      expect(result.exitCode, isNot(0), reason: url);
      expect('${result.stderr}', contains('placeholder'), reason: url);
    }
  });

  test('a host that only resembles the placeholder is accepted', () async {
    for (final url in [
      'https://api.myexample.com',
      'https://example.com.my-api.test',
      'https://my-api.test/example.com',
      'https://[2001:db8::1]:8443/v1',
    ]) {
      final result = await _resolve(['production', url]);

      expect(result.exitCode, 0, reason: '$url: ${result.stderr}');
      expect(result.stdout, 'BASE_URL=$url');
    }
  });

  test('a URL that is not absolute https is refused', () async {
    for (final url in [
      'http://api.my-api.test',
      'api.my-api.test',
      'https://',
      'https:///v1',
      'ws://api.my-api.test',
    ]) {
      final result = await _resolve(['staging', url]);

      expect(result.exitCode, isNot(0), reason: url);
      expect(result.stdout, isEmpty, reason: url);
    }
  });

  test('an environment that is not a release environment is refused', () async {
    final result = await _resolve(['development', 'https://api.my-api.test']);

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('staging or production'));
  });

  test(
    'build_all.sh refuses before calling flutter when the URL is unset',
    () async {
      final dir = Directory.systemTemp.createTempSync('build_all_url_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bin = Directory('${dir.path}/bin')..createSync();
      final log = File('${dir.path}/flutter.log');
      final stub = File('${bin.path}/flutter')
        ..writeAsStringSync('#!/bin/bash\necho "\$*" >> "\$STUB_LOG"\n');
      Process.runSync('chmod', ['+x', stub.path]);
      Directory('${dir.path}/scripts/ci').createSync(recursive: true);
      for (final script in [
        'build_all.sh',
        'ssl_pinning_defines.sh',
        'release_base_url.sh',
      ]) {
        File('scripts/ci/$script').copySync('${dir.path}/scripts/ci/$script');
      }

      Future<ProcessResult> run(String environment, Map<String, String> env) =>
          Process.run(
            'bash',
            ['scripts/ci/build_all.sh', environment],
            workingDirectory: dir.path,
            environment: {
              'PATH': '${bin.path}:${Platform.environment['PATH']}',
              'STUB_LOG': log.path,
              'OSTYPE': 'linux-gnu',
              'ENABLE_SSL_PINNING': 'false',
              'BASE_URL_STAGING': '',
              'BASE_URL_PRODUCTION': '',
              ...env,
            },
          );

      final unset = await run('staging', {
        'BASE_URL_PRODUCTION': 'https://api.production.test',
      });
      final placeholder = await run('production', {
        'BASE_URL_PRODUCTION': 'https://api.example.com',
      });

      expect(unset.exitCode, isNot(0));
      expect('${unset.stderr}', contains('BASE_URL_STAGING'));
      expect(placeholder.exitCode, isNot(0));
      expect('${placeholder.stderr}', contains('placeholder'));
      expect(log.existsSync(), isFalse, reason: 'flutter was never called');
    },
  );

  test('no build script or workflow carries a placeholder base URL', () {
    final offenders = <String>[
      for (final dir in ['scripts/ci', '.github/workflows'])
        for (final file in Directory(dir).listSync().whereType<File>())
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (RegExp(r'''BASE_URL\S*=\S*example\.com''').hasMatch(line) ||
                RegExp(r'''BASE_URL\S*:-https?://''').hasMatch(line))
              '${file.path}:${index + 1}: ${line.trim()}',
    ];

    expect(offenders, isEmpty);
  });

  test('every build.yml build resolves its URL through the helper', () {
    final file = File('.github/workflows/build.yml');
    if (!file.existsSync()) {
      markTestSkipped('build.yml is not in this tree');
      return;
    }
    final workflow = file.readAsStringSync();
    // The release builds continue onto their --dart-define lines; the debug
    // smoke build is a single line and takes no URL.
    final builds = RegExp(
      r'^\s+flutter build (apk|ios|web) \\$',
      multiLine: true,
    ).allMatches(workflow).length;
    const resolved =
        r'release_base_url "$ENVIRONMENT" "$INPUT_BASE_URL" || exit 1';

    expect(builds, greaterThan(0));
    expect(resolved.allMatches(workflow).length, builds);
  });
}
