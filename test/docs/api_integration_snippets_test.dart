// api-integration.md's self-contained snippets must compile against this
// repository. They imported only `core/di/providers.dart`, which exports
// nothing, and used ApiClient and the auth use-case providers from it; the
// retry helper returned a variable declared inside its loop. Every fenced
// `dart` block that starts with an `import` is analyzed: zero errors and
// warnings.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'doc_snippets.dart';

void main() {
  test('every self-contained dart snippet in api-integration.md analyzes with '
      'no error or warning', () {
    final blocks = importingDartBlocks(
      File('docs/api/examples/api-integration.md').readAsStringSync(),
    );
    expect(blocks, isNotEmpty);

    final problems = analyzeSnippets('api_integration', blocks);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
