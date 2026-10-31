import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_starter/core/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/core/accessibility/accessibility_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Accessibility testing helpers
///
/// Provides utilities for testing accessibility features in Flutter widgets.
class AccessibilityTestHelpers {
  AccessibilityTestHelpers._();

  /// Check if a widget has proper semantic labels
  ///
  /// Returns true if the widget has a non-empty semantic label.
  static bool hasSemanticLabel(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    final label = semantics.label;
    return label.isNotEmpty;
  }

  /// Check if a widget is marked as a button
  static bool isButton(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    return semantics.flagsCollection.isButton;
  }

  /// Check if a widget is enabled
  static bool isEnabled(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    return semantics.flagsCollection.isEnabled == Tristate.isTrue;
  }

  /// Check if a widget has minimum touch target size
  ///
  /// Checks if the widget's size meets the minimum touch target requirements.
  static bool hasMinTouchTarget(WidgetTester tester, Finder finder) {
    final renderObject = tester.renderObject(finder);
    if (renderObject is! RenderBox) return false;

    final size = renderObject.size;
    return size.width >= AccessibilityConstants.minTouchTargetSize &&
        size.height >= AccessibilityConstants.minTouchTargetSize;
  }

  /// Check if text has sufficient contrast ratio
  ///
  /// Checks if the text color meets WCAG AA standards for normal text.
  static bool hasSufficientContrast(Color foreground, Color background) {
    return AccessibilityHelpers.meetsContrastRatioAA(foreground, background);
  }

  /// Get semantic label from a widget
  static String? getSemanticLabel(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    return semantics.label;
  }

  /// Get semantic hint from a widget
  static String? getSemanticHint(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    return semantics.hint;
  }

  /// Check if a widget is marked as a header
  static bool isHeader(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    return semantics.flagsCollection.isHeader;
  }

  /// Check if a widget is marked as an image
  static bool isImage(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    return semantics.flagsCollection.isImage;
  }

  /// Verify all interactive elements have semantic labels
  ///
  /// Fails the test when a node with a tap or long-press action has no
  /// label, using Flutter's [labeledTapTargetGuideline]. Semantics must be on:
  /// call `tester.ensureSemantics()` before pumping.
  static Future<void> verifyInteractiveElementsHaveLabels(
    WidgetTester tester,
  ) async {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  }

  /// Verify minimum touch target sizes
  ///
  /// Checks that all interactive elements meet minimum touch target
  /// requirements.
  static Future<void> verifyMinTouchTargets(WidgetTester tester) async {
    // Find all buttons and check their sizes
    final buttons = find.byType(ElevatedButton);
    for (final button in buttons.evaluate()) {
      final renderObject = tester.renderObject(find.byWidget(button.widget));
      if (renderObject is RenderBox) {
        final size = renderObject.size;
        expect(
          size.width,
          greaterThanOrEqualTo(AccessibilityConstants.minTouchTargetSize),
          reason:
              'Button width must be at least '
              '${AccessibilityConstants.minTouchTargetSize}',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(AccessibilityConstants.minTouchTargetSize),
          reason:
              'Button height must be at least '
              '${AccessibilityConstants.minTouchTargetSize}',
        );
      }
    }
  }

  /// Verify contrast ratios for text
  ///
  /// Checks that text colors meet WCAG AA contrast requirements.
  static void verifyTextContrast(
    Color textColor,
    Color backgroundColor,
    String context,
  ) {
    final contrastRatio = AccessibilityHelpers.getContrastRatio(
      textColor,
      backgroundColor,
    );

    expect(
      contrastRatio,
      greaterThanOrEqualTo(AccessibilityConstants.minContrastRatioNormal),
      reason:
          'Text contrast ratio in $context is $contrastRatio, '
          'which is below the minimum required '
          '${AccessibilityConstants.minContrastRatioNormal}',
    );
  }
}

/// Custom matchers for accessibility testing
///
/// Each matches the [SemanticsNode] of a widget, as returned by
/// `tester.getSemantics(finder)`:
///
/// ```dart
/// expect(
///   tester.getSemantics(find.text('Submit')),
///   AccessibilityMatchers.isButton(),
/// );
/// ```
class AccessibilityMatchers {
  AccessibilityMatchers._();

  /// Matches a node whose label is [label], or any non-empty label when
  /// [label] is null.
  static Matcher hasSemanticLabel([String? label]) =>
      label == null ? const _NonEmptyLabelMatcher() : isSemantics(label: label);

  /// Matches a node flagged as a button.
  static Matcher isButton() => isSemantics(isButton: true);

  /// Matches a node that has an enabled state and is enabled.
  static Matcher isEnabled() =>
      isSemantics(hasEnabledState: true, isEnabled: true);

  /// Matches a node at least [AccessibilityConstants.minTouchTargetSize]
  /// logical pixels wide and high.
  static Matcher hasMinTouchTarget() => const _MinTouchTargetMatcher();
}

class _NonEmptyLabelMatcher extends Matcher {
  const _NonEmptyLabelMatcher();

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item is SemanticsNode && item.label.isNotEmpty;

  @override
  Description describe(Description description) =>
      description.add('a semantics node with a non-empty label');
}

class _MinTouchTargetMatcher extends Matcher {
  const _MinTouchTargetMatcher();

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! SemanticsNode) return false;
    final size = item.rect.size;
    return size.width >= AccessibilityConstants.minTouchTargetSize &&
        size.height >= AccessibilityConstants.minTouchTargetSize;
  }

  @override
  Description describe(Description description) => description.add(
    'a semantics node at least '
    '${AccessibilityConstants.minTouchTargetSize} logical pixels square',
  );

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) => item is SemanticsNode
      ? mismatchDescription.add('is ${item.rect.size}')
      : mismatchDescription.add('is not a SemanticsNode');
}
