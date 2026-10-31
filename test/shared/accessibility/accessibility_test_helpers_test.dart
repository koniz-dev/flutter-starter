// The accessibility matchers used to match anything, isEnabled always
// answered false, and verifyInteractiveElementsHaveLabels checked nothing, so
// a test built on them could not fail. Each is pinned on a widget that has
// the property and one that does not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'accessibility_test_helpers.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

/// Whether [matcher] matches [item].
bool _matches(Matcher matcher, Object? item) => matcher.matches(item, {});

final Finder _labelled = find.byKey(const Key('labelled'));
final Finder _plain = find.byKey(const Key('plain'));

void main() {
  group('AccessibilityMatchers', () {
    testWidgets('hasSemanticLabel', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          children: [
            Semantics(
              key: const Key('labelled'),
              container: true,
              label: 'Submit',
              child: const SizedBox(width: 10, height: 10),
            ),
            Semantics(
              key: const Key('plain'),
              container: true,
              child: const SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      );

      final labelled = tester.getSemantics(_labelled);
      final plain = tester.getSemantics(_plain);
      expect(labelled, AccessibilityMatchers.hasSemanticLabel('Submit'));
      expect(labelled, AccessibilityMatchers.hasSemanticLabel());
      expect(
        _matches(AccessibilityMatchers.hasSemanticLabel('Other'), labelled),
        isFalse,
      );
      expect(
        _matches(AccessibilityMatchers.hasSemanticLabel(), plain),
        isFalse,
      );
      expect(_matches(AccessibilityMatchers.hasSemanticLabel(), 'x'), isFalse);
      handle.dispose();
    });

    testWidgets('isButton and isEnabled', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          children: [
            ElevatedButton(
              key: const Key('labelled'),
              onPressed: () {},
              child: const Text('On'),
            ),
            const ElevatedButton(
              key: Key('plain'),
              onPressed: null,
              child: Text('Off'),
            ),
            const Text('Just text'),
          ],
        ),
      );

      final enabled = tester.getSemantics(_labelled);
      final disabled = tester.getSemantics(_plain);
      final text = tester.getSemantics(find.text('Just text'));
      expect(enabled, AccessibilityMatchers.isButton());
      expect(enabled, AccessibilityMatchers.isEnabled());
      expect(disabled, AccessibilityMatchers.isButton());
      expect(_matches(AccessibilityMatchers.isEnabled(), disabled), isFalse);
      expect(_matches(AccessibilityMatchers.isButton(), text), isFalse);
      expect(_matches(AccessibilityMatchers.isEnabled(), text), isFalse);
      handle.dispose();
    });

    testWidgets('hasMinTouchTarget', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          children: [
            Semantics(
              key: const Key('labelled'),
              container: true,
              label: 'big',
              child: const SizedBox(width: 48, height: 48),
            ),
            Semantics(
              key: const Key('plain'),
              container: true,
              label: 'small',
              child: const SizedBox(width: 48, height: 20),
            ),
          ],
        ),
      );

      expect(
        tester.getSemantics(_labelled),
        AccessibilityMatchers.hasMinTouchTarget(),
      );
      expect(
        _matches(
          AccessibilityMatchers.hasMinTouchTarget(),
          tester.getSemantics(_plain),
        ),
        isFalse,
      );
      handle.dispose();
    });
  });

  group('AccessibilityTestHelpers', () {
    testWidgets('hasSemanticLabel, getSemanticLabel and getSemanticHint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          children: [
            Semantics(
              key: const Key('labelled'),
              container: true,
              label: 'Name',
              hint: 'Your full name',
              child: const SizedBox(width: 10, height: 10),
            ),
            Semantics(
              key: const Key('plain'),
              container: true,
              child: const SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      );

      expect(
        AccessibilityTestHelpers.hasSemanticLabel(tester, _labelled),
        isTrue,
      );
      expect(
        AccessibilityTestHelpers.hasSemanticLabel(tester, _plain),
        isFalse,
      );
      expect(
        AccessibilityTestHelpers.getSemanticLabel(tester, _labelled),
        'Name',
      );
      expect(
        AccessibilityTestHelpers.getSemanticHint(tester, _labelled),
        'Your full name',
      );
      expect(AccessibilityTestHelpers.getSemanticHint(tester, _plain), '');
      handle.dispose();
    });

    testWidgets('isButton and isEnabled', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          children: [
            ElevatedButton(
              key: const Key('labelled'),
              onPressed: () {},
              child: const Text('On'),
            ),
            const ElevatedButton(
              key: Key('plain'),
              onPressed: null,
              child: Text('Off'),
            ),
            const Text('Just text'),
          ],
        ),
      );

      expect(AccessibilityTestHelpers.isButton(tester, _labelled), isTrue);
      expect(
        AccessibilityTestHelpers.isButton(tester, find.text('Just text')),
        isFalse,
      );
      expect(AccessibilityTestHelpers.isEnabled(tester, _labelled), isTrue);
      expect(AccessibilityTestHelpers.isEnabled(tester, _plain), isFalse);
      handle.dispose();
    });

    testWidgets('isHeader and isImage', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          children: [
            Semantics(
              key: const Key('labelled'),
              container: true,
              header: true,
              image: true,
              label: 'Title',
              child: const SizedBox(width: 10, height: 10),
            ),
            Semantics(
              key: const Key('plain'),
              container: true,
              label: 'Body',
              child: const SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      );

      expect(AccessibilityTestHelpers.isHeader(tester, _labelled), isTrue);
      expect(AccessibilityTestHelpers.isHeader(tester, _plain), isFalse);
      expect(AccessibilityTestHelpers.isImage(tester, _labelled), isTrue);
      expect(AccessibilityTestHelpers.isImage(tester, _plain), isFalse);
      handle.dispose();
    });

    testWidgets('hasMinTouchTarget', (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            SizedBox(key: Key('labelled'), width: 48, height: 48),
            SizedBox(key: Key('plain'), width: 20, height: 48),
          ],
        ),
      );

      expect(
        AccessibilityTestHelpers.hasMinTouchTarget(tester, _labelled),
        isTrue,
      );
      expect(
        AccessibilityTestHelpers.hasMinTouchTarget(tester, _plain),
        isFalse,
      );
    });

    test('hasSufficientContrast and verifyTextContrast', () {
      expect(
        AccessibilityTestHelpers.hasSufficientContrast(
          Colors.black,
          Colors.white,
        ),
        isTrue,
      );
      expect(
        AccessibilityTestHelpers.hasSufficientContrast(
          const Color(0xFFBBBBBB),
          Colors.white,
        ),
        isFalse,
      );
      AccessibilityTestHelpers.verifyTextContrast(
        Colors.black,
        Colors.white,
        'black on white',
      );
      expect(
        () => AccessibilityTestHelpers.verifyTextContrast(
          const Color(0xFFBBBBBB),
          Colors.white,
          'grey on white',
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    testWidgets('verifyInteractiveElementsHaveLabels passes a labelled '
        'button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ElevatedButton(onPressed: () {}, child: const Text('Save')),
      );

      await AccessibilityTestHelpers.verifyInteractiveElementsHaveLabels(
        tester,
      );
      handle.dispose();
    });

    testWidgets('verifyInteractiveElementsHaveLabels fails an unlabelled '
        'tap target', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        GestureDetector(
          onTap: () {},
          child: const SizedBox(width: 48, height: 48),
        ),
      );

      await expectLater(
        AccessibilityTestHelpers.verifyInteractiveElementsHaveLabels(tester),
        throwsA(isA<TestFailure>()),
      );
      handle.dispose();
    });

    testWidgets('verifyMinTouchTargets', (tester) async {
      await _pump(
        tester,
        ElevatedButton(onPressed: () {}, child: const Text('Save')),
      );
      await AccessibilityTestHelpers.verifyMinTouchTargets(tester);

      await _pump(
        tester,
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(20, 20),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
          onPressed: () {},
          child: const SizedBox(width: 10, height: 10),
        ),
      );
      await expectLater(
        AccessibilityTestHelpers.verifyMinTouchTargets(tester),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
