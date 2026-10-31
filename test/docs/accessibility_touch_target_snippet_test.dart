// The touch-target test in docs/guides/accessibility/testing-procedures.md
// called `tester.getRenderObject`, which WidgetTester does not have, and read
// `.size` from a RenderObject. The documented test is now the one below: this
// file runs it, and checks the document shows exactly this code.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `testWidgets(...)` call in [text] whose description is [name], with
/// its indentation removed.
String? _testCall(String text, String name) {
  final lines = text.split('\n');
  final start = lines.indexWhere((l) => l.contains("testWidgets('$name'"));
  if (start == -1) return null;
  final indent = lines[start].length - lines[start].trimLeft().length;
  final end = lines.indexWhere(
    (l) => l.length > indent && l.substring(indent).startsWith('});'),
    start,
  );
  return [
    for (final l in lines.sublist(start, end + 1))
      l.replaceFirst(RegExp('^ {0,$indent}'), ''),
  ].join('\n');
}

const _name = 'button meets minimum touch target';

void main() {
  // snippet: the documented test, unchanged.
  testWidgets('button meets minimum touch target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AccessibleButton(label: 'Submit', onPressed: () {}),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(AccessibleButton));
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  test('the guide shows the test this file runs', () {
    final documented = _testCall(
      File(
        'docs/guides/accessibility/testing-procedures.md',
      ).readAsStringSync(),
      _name,
    );
    final run = _testCall(
      File(
        'test/docs/accessibility_touch_target_snippet_test.dart',
      ).readAsStringSync(),
      _name,
    );

    expect(run, isNotNull);
    expect(documented, run);
  });
}
