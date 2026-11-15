@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Enable the actual template steps, retaining comments inside their scripts.
String uncommentSteps(String source) => source
    .split('\n')
    .map((line) {
      if (line == '      #') return '';
      return line.replaceFirst(RegExp('^      # (?=- name:|  )'), '      ');
    })
    .join('\n');

const workflows = [
  '.github/workflows/deploy-android.yml',
  '.github/workflows/deploy-ios.yml',
  '.github/workflows/deploy-web.yml',
];

List<({String name, Map<dynamic, dynamic> step})> buildSteps() {
  final result = <({String name, Map<dynamic, dynamic> step})>[];
  for (final file in workflows) {
    final workflow =
        loadYaml(uncommentSteps(File(file).readAsStringSync())) as YamlMap;
    final jobs = workflow['jobs'] as YamlMap;
    for (final job in jobs.entries) {
      for (final step
          in ((job.value as YamlMap)['steps'] as YamlList).cast<YamlMap>()) {
        if (RegExp(r'\bflutter build ').hasMatch('${step['run']}')) {
          result.add((name: '$file:${job.key}', step: step));
        }
      }
    }
  }
  return result;
}

/// Substitute only the contexts these templates use; evaluate || as Actions
/// does for nonempty URL strings, so variables and secret fallbacks are tested.
String expand(String source, Map<String, String> contexts) =>
    source.replaceAllMapped(RegExp(r'\$\{\{\s*(.*?)\s*\}\}'), (match) {
      for (final term in match[1]!.split('||')) {
        final key = term.trim();
        if (!contexts.containsKey(key)) {
          throw StateError('Unmodelled template context: $key');
        }
        final value = contexts[key]!;
        if (value.isNotEmpty) return value;
      }
      return '';
    });

void main() {
  final builds = buildSteps();

  test('all five commented deploy builds are exercised', () {
    expect(builds, hasLength(5));
    expect(builds.map((b) => b.name).toSet(), hasLength(5));
  });

  for (final build in builds) {
    test(
      '${build.name} refuses invalid URLs before invoking flutter',
      () async {
        final scratch = Directory.systemTemp.createTempSync('deploy_url_');
        addTearDown(() => scratch.deleteSync(recursive: true));
        final bin = Directory('${scratch.path}/bin')..createSync();
        final log = File('${scratch.path}/flutter.log');
        final stub = File('${bin.path}/flutter')
          ..writeAsStringSync(
            '#!/bin/bash\nprintf "%s\\n" "\$@" >> "\$STUB_LOG"\n',
          );
        expect((await Process.run('chmod', ['+x', stub.path])).exitCode, 0);
        Directory('${scratch.path}/scripts/ci').createSync(recursive: true);
        for (final name in ['release_base_url.sh', 'ssl_pinning_defines.sh']) {
          File('scripts/ci/$name').copySync('${scratch.path}/scripts/ci/$name');
        }

        Future<ProcessResult> run(
          String environment,
          Map<String, String> values,
        ) {
          if (log.existsSync()) log.deleteSync();
          final contexts = {
            'steps.env.outputs.environment': environment,
            'vars.BASE_URL_STAGING': '',
            'vars.BASE_URL_PRODUCTION': '',
            'secrets.BASE_URL_STAGING': '',
            'secrets.BASE_URL_PRODUCTION': '',
            'vars.API_SSL_FINGERPRINTS': '',
            'secrets.APP_STORE_CONNECT_API_KEY_ID': '',
            'secrets.APP_STORE_CONNECT_ISSUER_ID': '',
            'secrets.APPLE_TEAM_ID': '',
            ...values,
          };
          return Process.run(
            'bash',
            [
              '-e',
              '-o',
              'pipefail',
              '-c',
              expand('${build.step['run']}', contexts),
            ],
            workingDirectory: scratch.path,
            environment: {
              'PATH': '${bin.path}:${Platform.environment['PATH']}',
              'STUB_LOG': log.path,
              'ENABLE_SSL_PINNING': 'false',
              'BASE_URL': '',
              'BASE_URL_STAGING': '',
              'BASE_URL_PRODUCTION': '',
              for (final entry in (build.step['env'] as YamlMap).entries)
                '${entry.key}': expand('${entry.value}', contexts),
            },
          );
        }

        for (final environment in ['staging', 'production']) {
          final suffix = environment.toUpperCase();
          for (final invalid in [
            '',
            'http://api.acme.test',
            'https://api.example.com',
          ]) {
            final result = await run(environment, {
              'secrets.BASE_URL_$suffix': invalid,
            });
            expect(result.exitCode, isNot(0), reason: '$environment/$invalid');
            expect(
              log.existsSync(),
              isFalse,
              reason: 'No flutter invocation on refusal',
            );
            expect('${result.stderr}', isNotEmpty);
          }

          for (final values in <Map<String, String>>[
            {'vars.BASE_URL_$suffix': 'https://variable.acme.test'},
            {'secrets.BASE_URL_$suffix': 'https://secret.acme.test'},
            {
              'vars.BASE_URL_$suffix': 'https://variable.acme.test',
              'secrets.BASE_URL_$suffix': 'https://secret.acme.test',
            },
          ]) {
            final result = await run(environment, values);
            expect(result.exitCode, 0, reason: '${result.stderr}');
            final selected =
                values['vars.BASE_URL_$suffix'] ??
                values['secrets.BASE_URL_$suffix'];
            expect(
              log.readAsLinesSync(),
              contains('--dart-define=BASE_URL=$selected'),
            );
            expect(
              log.readAsLinesSync(),
              contains('--dart-define=ENVIRONMENT=$environment'),
            );
          }
        }
      },
    );
  }

  test('Vercel deploys the built web directory', () {
    final workflow = loadYaml(
      uncommentSteps(File(workflows.last).readAsStringSync()),
    ) as YamlMap;
    final jobs = workflow['jobs'] as YamlMap;
    final deploy = [
      for (final job in jobs.values)
        for (final step
            in ((job as YamlMap)['steps'] as YamlList).cast<YamlMap>())
          if ('${step['uses']}'.startsWith('amondnet/vercel-action@')) step,
    ].single;
    expect((deploy['with'] as YamlMap)['working-directory'], 'build/web');
  });
}
