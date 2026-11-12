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
  (
    // `mason get`, `"$MASON" make`, a path ending in /mason, or the CLI
    // package - but not the file name `mason.yaml` in a message.
    use: RegExp(
      r'''(^|[\s/"'{])mason["'}]?\s+[a-z]|\bmason_cli\b''',
      multiLine: true,
    ),
    file: 'mason.yaml',
  ),
  (
    // On one line or continued onto the next.
    use: RegExp(r'\bdart\b[^\n]*(\\\n[^\n]*)?strip_sample_features\.dart'),
    file: 'tool/strip_sample_features.dart',
  ),
];

final RegExp _guardTerm = RegExp(r"^hashFiles\('[^']+'\) != ''$");

/// Whether [condition] skips the step when [file] is gone: every `&&` term is
/// a `hashFiles(...) != ''` test and one of them names [file]. Anything
/// looser - an `||`, say - could run the step without the file.
bool _guards(String condition, String file) {
  final terms = condition.split('&&').map((term) => term.trim()).toList();
  return terms.every(_guardTerm.hasMatch) &&
      terms.contains("hashFiles('$file') != ''");
}

/// The steps of [workflow] that use a strippable file without the guard, as
/// `job / step: file`.
List<String> _unguarded(String workflow) {
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  return [
    for (final job in jobs.entries)
      for (final step in (job.value as YamlMap)['steps'] as YamlList)
        for (final need in _needs)
          if (need.use.hasMatch('${(step as YamlMap)['run'] ?? ''}') &&
              !_guards('${step['if'] ?? ''}', need.file))
            '${job.key} / ${step['name']}: ${need.file}',
  ];
}

void main() {
  test('an unguarded Mason or strip step is reported', () {
    const workflow = r'''
jobs:
  probe:
    steps:
      - name: guarded
        if: hashFiles('mason.yaml') != ''
        run: mason get
      - name: guarded twice
        if: hashFiles('mason.yaml') != '' && hashFiles('tool/strip_sample_features.dart') != ''
        run: |
          mason get
          dart run tool/strip_sample_features.dart --apply
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
      - name: names the file only
        run: echo "mason.yaml is gone"
      - name: loose guard
        if: hashFiles('mason.yaml') != '' || true
        run: mason get
      - name: other spellings
        run: |
          "$MASON" make feature_clean
          $HOME/.pub-cache/bin/mason  upgrade
      - name: strip by another spelling
        run: |
          dart run \
            ./tool/strip_sample_features.dart --apply
''';

    expect(_unguarded(workflow), [
      'probe / bare mason: mason.yaml',
      'probe / installs the cli: mason.yaml',
      'probe / bare strip: tool/strip_sample_features.dart',
      'probe / loose guard: mason.yaml',
      'probe / other spellings: mason.yaml',
      'probe / strip by another spelling: tool/strip_sample_features.dart',
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

  // In the template both files always exist, so a job that skipped its steps
  // there would be green having verified nothing.
  test('the notice step fails in the template repository', () {
    final file = File('.github/workflows/scripts-smoke.yml');
    if (!file.existsSync()) {
      markTestSkipped('scripts-smoke.yml is not in this tree');
      return;
    }
    final jobs =
        (loadYaml(file.readAsStringSync()) as YamlMap)['jobs'] as YamlMap;
    final notices = [
      for (final job in ['setup-brick', 'manual-rename'])
        for (final step in (jobs[job] as YamlMap)['steps'] as YamlList)
          if ('${(step as YamlMap)['if'] ?? ''}'.contains("== ''")) step,
    ];

    expect(notices, hasLength(2));
    for (final step in notices) {
      expect(
        '${(step['env'] as YamlMap)['IS_TEMPLATE']}',
        r'${{ github.event.repository.is_template }}',
      );
      expect('${step['run']}', contains(r'if [ "$IS_TEMPLATE" = "true" ]'));
      expect('${step['run']}', contains('exit 1'));
    }
  });
}
