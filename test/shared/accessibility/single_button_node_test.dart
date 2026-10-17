import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// koniz-dev/flutter-starter#351: AccessibleButton and AccessibleIconButton
// wrapped a Material button - which makes its own button node - in a second
// `Semantics(button: true)`. A screen reader got two focus stops for one
// control, and the outer one had no tap action.

/// Every semantics node flagged as a button, in tree order.
List<SemanticsNode> _buttonNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  bool visit(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isButton) nodes.add(node);
    node.visitChildren(visit);
    return true;
  }

  visit(_owner(tester).rootSemanticsNode!);
  return nodes;
}

/// The test view's semantics owner.
SemanticsOwner _owner(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!;

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('AccessibleButton', () {
    testWidgets('criterion 1: one button node, carrying the label and the '
        'tap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        AccessibleButton(label: 'Retry', onPressed: () => taps++),
      );

      final nodes = _buttonNodes(tester);
      expect(nodes, hasLength(1));
      final data = nodes.single.getSemanticsData();
      expect(data.label, contains('Retry'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(
        data.flagsCollection.isFocused,
        isNot(Tristate.none),
        reason: 'the Material node it replaces was focusable',
      );

      _owner(tester).performAction(
        nodes.single.id,
        SemanticsAction.tap,
      );
      expect(taps, 1, reason: 'the semantics tap reaches onPressed');
      handle.dispose();
    });

    testWidgets('criterion 2: disabled is reflected in the single node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AccessibleButton(label: 'Retry', onPressed: () {}, isEnabled: false),
      );

      final nodes = _buttonNodes(tester);
      expect(nodes, hasLength(1));
      final data = nodes.single.getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('criterion 2: loading is reflected in the single node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AccessibleButton(label: 'Retry', onPressed: () {}, isLoading: true),
      );

      final nodes = _buttonNodes(tester);
      expect(nodes, hasLength(1));
      final data = nodes.single.getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(
        data.label,
        isNot('Retry'),
        reason: 'the effective label states the loading state',
      );
      handle.dispose();
    });
  });

  group('AccessibleIconButton', () {
    testWidgets('criterion 1: one button node, carrying the label and the '
        'tap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        AccessibleIconButton(
          icon: Icons.language,
          semanticLabel: 'Select language',
          onPressed: () => taps++,
        ),
      );

      final nodes = _buttonNodes(tester);
      expect(nodes, hasLength(1));
      final data = nodes.single.getSemanticsData();
      expect(data.label, 'Select language');
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      _owner(tester).performAction(
        nodes.single.id,
        SemanticsAction.tap,
      );
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('criterion 2: disabled is reflected in the single node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AccessibleIconButton(
          icon: Icons.language,
          semanticLabel: 'Select language',
          onPressed: () {},
          isEnabled: false,
        ),
      );

      final nodes = _buttonNodes(tester);
      expect(nodes, hasLength(1));
      final data = nodes.single.getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });

  testWidgets('criterion 3: HomeScreen meets labeledTapTargetGuideline', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
