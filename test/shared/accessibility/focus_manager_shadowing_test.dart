// Regression test for koniz-dev/flutter-starter#65, criterion 1.
//
// This file imports `package:flutter/material.dart` and
// `accessibility_widgets.dart` **without a prefix** and uses
// `FocusManager.instance`. That is the exact combination that failed to
// compile while `accessibility_widgets.dart` declared its own
// `class FocusManager`: `'FocusManager' is imported from both ...`. If the
// widget is ever renamed back, this file stops compiling - the failure is the
// assertion.
import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accessibility_widgets does not shadow Flutter FocusManager', () {
    testWidgets("FocusManager.instance is Flutter's singleton", (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleFocus(child: TextField(autofocus: true)),
          ),
        ),
      );
      await tester.pump();

      // Resolves to the framework class, not to anything in this repository.
      expect(FocusManager.instance, isA<FocusManager>());
      final focusedField = FocusManager.instance.primaryFocus;
      expect(focusedField, isNotNull);

      // The canonical "dismiss the keyboard" call from the issue report.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(
        focusedField!.hasFocus,
        isFalse,
        reason: 'unfocus() should have dropped focus off the text field',
      );
    });

    testWidgets('AccessibleFocus still wraps its child in a Focus', (
      tester,
    ) async {
      var focusChanges = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleFocus(
              autofocus: true,
              onFocusChange: (_) => focusChanges++,
              child: const Text('Child'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Focus), findsWidgets);
      expect(find.text('Child'), findsOneWidget);
      expect(focusChanges, greaterThan(0));
    });
  });
}
