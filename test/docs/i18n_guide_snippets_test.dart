// The internationalization guide's code must compile against this repository
// (koniz-dev/flutter-starter#359).
//
// It imported `package:flutter_gen/gen_l10n/app_localizations.dart`, which
// does not exist here (the app generates into lib/l10n/), set a notifier's
// protected `state`, and listed three languages where there are four. This
// analyzes every fenced `dart` block that starts with an `import` - the
// self-contained ones - and checks the language list against lib/l10n.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'doc_snippets.dart';

const _guide = 'docs/guides/features/internationalization-guide.md';

void main() {
  final markdown = File(_guide).readAsStringSync();

  test('criterion 2: every self-contained dart snippet analyzes with no '
      'error or warning', () {
    final blocks = importingDartBlocks(markdown);
    expect(blocks, isNotEmpty, reason: 'the guide has importing snippets');

    final problems = analyzeSnippets('i18n_guide', blocks);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('criterion 1: no snippet or note names flutter_gen', () {
    expect(markdown, isNot(contains('flutter_gen')));
  });

  test('criterion 3: the language list matches lib/l10n/app_*.arb', () {
    final codes =
        Directory('lib/l10n')
            .listSync()
            .map((e) => e.path.split('/').last)
            .map(RegExp(r'^app_([a-z]{2,3})\.arb$').firstMatch)
            .whereType<RegExpMatch>()
            .map((m) => m.group(1)!)
            .toList()
          ..sort();
    expect(codes, isNotEmpty);

    final line = RegExp(
      r'^- \*\*(\d+) Languages\*\*: (.*)$',
      multiLine: true,
    ).firstMatch(markdown);
    expect(line, isNotNull, reason: 'the overview states the languages');
    expect(int.parse(line!.group(1)!), codes.length);
    final listed = RegExp(
      r'\(([a-z]{2,3})\)',
    ).allMatches(line.group(2)!).map((m) => m.group(1)!).toList()..sort();
    expect(listed, codes);
  });
}
