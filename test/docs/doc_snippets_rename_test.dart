// The doc-snippet tests must keep passing in a renamed fork:
// the docs keep importing the template's
// package, and the shared analyzer points those imports at the fork's.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'doc_snippets.dart';

void main() {
  test('template imports are pointed at the given package, others kept', () {
    // Built from templatePackage, not written out: a rename rewrites every
    // literal `package:flutter_starter/` in .dart files, this test's input
    // included, and then there is nothing left to point anywhere.
    // The target is a name no rename uses.
    const block =
        '''
import 'package:$templatePackage/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
''';

    expect(forPackage(block, 'zz_target_app'), '''
import 'package:zz_target_app/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
''');
  });

  test('the template name survives both rename paths', () {
    // Both rewrite every contiguous `package:flutter_starter/` in .dart files.
    // The constant must not be spelled that way, or a rename turns it into the
    // fork's own name and the rewrite above into a no-op.
    final line = File('test/docs/doc_snippets.dart')
        .readAsLinesSync()
        .singleWhere((l) => l.contains('const String templatePackage'));
    expect(line, isNot(contains('flutter_starter')));
    expect(templatePackage, 'flutter_${'starter'}');
  });

  test('a snippet importing the template package analyzes clean here', () {
    const block =
        '''
import 'package:$templatePackage/core/utils/result.dart';

Result<int> ok() => const Success(1);
''';

    expect(analyzeSnippets('rename_probe', [block]), isEmpty);
  });
}
