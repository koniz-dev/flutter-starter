// The testing guide's and CONTRIBUTING's code must compile against this
// repository.
//
// They imported `package:flutter_starter/test/helpers/...`, which cannot
// resolve - test/ is not part of the package - and read the result of
// `AuthNotifier.login`, which returns `Future<void>`. Every fenced `dart`
// block that starts with an `import` is analyzed: zero errors and warnings.
// `test/helpers` is imported relatively, as a test two levels below test/
// would (`../../helpers/...`).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'doc_snippets.dart';

void main() {
  for (final (name, path) in const [
    ('testing_guide', 'docs/guides/testing/guide.md'),
    ('contributing', 'CONTRIBUTING.md'),
  ]) {
    test('criterion 1: every self-contained dart snippet in $path analyzes '
        'with no error or warning', () {
      final blocks = importingDartBlocks(File(path).readAsStringSync());
      expect(blocks, isNotEmpty);

      final problems = analyzeSnippets(name, blocks);
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  test('no snippet imports test/ through the package', () {
    for (final path in const [
      'docs/guides/testing/guide.md',
      'CONTRIBUTING.md',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('package:flutter_starter/test/')),
        reason: path,
      );
    }
  });
}
