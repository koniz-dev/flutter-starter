// The sample strip deletes tool/strip_sample_features.dart, and with
// --remove-bricks also bricks/ and mason.yaml, but leaves
// .github/workflows/scripts-smoke.yml in place. Its setup-brick and
// manual-rename jobs then ran `mason get` and the strip tool against files
// that were gone, so a dispatch with the default `job: all` went red in a
// stripped project. Every step that needs one of those files is now skipped
// when the file is absent.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// What a step's script needs, and the file whose presence stands for it.
final _needs = <({RegExp use, String file})>[
  (use: RegExp(r'\bmason (get|make)\b|\bmason_cli\b'), file: 'mason.yaml'),
  (
    use: RegExp(r'dart run tool/strip_sample_features\.dart'),
    file: 'tool/strip_sample_features.dart',
  ),
];

/// The steps of [workflow] that use a strippable file without the guard, as
/// `job / step: file`.
List<String> _unguarded(String workflow) {
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  return [
    for (final job in jobs.entries)
      for (final step in (job.value as YamlMap)['steps'] as YamlList)
        for (final need in _needs)
          if (need.use.hasMatch('${(step as YamlMap)['run'] ?? ''}') &&
              !'${step['if'] ?? ''}'.contains(
                "hashFiles('${need.file}') != ''",
              ))
            '${job.key} / ${step['name']}: ${need.file}',
  ];
}

void main() {
  test('an unguarded Mason or strip step is reported', () {
    const workflow = '''
jobs:
  probe:
    steps:
      - name: guarded
        if: hashFiles('mason.yaml') != ''
        run: mason get
      - name: bare mason
        run: |
          mason make feature_clean
      - name: installs the cli
        run: dart pub global activate mason_cli
      - name: bare strip
        if: hashFiles('mason.yaml') != ''
        run: dart run tool/strip_sample_features.dart --apply
      - name: unrelated
        run: flutter analyze
''';

    expect(_unguarded(workflow), [
      'probe / bare mason: mason.yaml',
      'probe / installs the cli: mason.yaml',
      'probe / bare strip: tool/strip_sample_features.dart',
    ]);
  });

  test('every scripts-smoke step that needs Mason or the strip tool is '
      'skipped when the file it needs is gone', () {
    final file = File('.github/workflows/scripts-smoke.yml');
    if (!file.existsSync()) {
      markTestSkipped('scripts-smoke.yml is not in this tree');
      return;
    }

    expect(_unguarded(file.readAsStringSync()), isEmpty);
  });
}
