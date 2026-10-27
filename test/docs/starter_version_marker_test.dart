// The upgrade guide opens with the starter release a copy of the template came
// from. A project built on the starter changes its own `pubspec.yaml` version
// on its first release, so this line is the only record of where it started,
// and Step 1 of the guide reads it. Releases are tagged `v<version>` upstream,
// so the line must name one in that form.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _guide = 'docs/guides/migration/upgrading-this-starter.md';
final _marker = RegExp(r'^\*\*Starter version:\*\* (v\d+\.\d+\.\d+)$');

void main() {
  test('the upgrade guide names one starter release, before its first '
      'section', () {
    final lines = File(_guide).readAsLinesSync();
    final markers = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].startsWith('**Starter version:**')) (i, lines[i]),
    ];

    expect(markers, hasLength(1), reason: 'exactly one marker line');
    final (index, line) = markers.single;
    expect(
      line,
      matches(_marker),
      reason: 'the tag form, e.g. **Starter version:** v2.0.0',
    );
    final firstSection = lines.indexWhere((l) => l.startsWith('## '));
    expect(index, lessThan(firstSection), reason: 'Step 1 says it is on top');
  });

  test('Step 1 reads the marker, not pubspec.yaml', () {
    final guide = File(_guide).readAsStringSync();
    final step1 = guide.substring(
      guide.indexOf('### Step 1'),
      guide.indexOf('### Step 2'),
    );
    expect(step1, contains("grep -m1 'Starter version' $_guide"));
    expect(step1, isNot(contains('grep version')));
  });
}
