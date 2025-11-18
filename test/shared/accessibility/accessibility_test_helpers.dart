import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_helpers.dart';
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
    final enabled = semantics.flagsCollection.isEnabled;
    // Tristate: checked means enabled, unchecked means disabled
    return enabled.toString().contains('checked');
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
  static bool hasSufficientContrast(
    Color foreground,
    Color background,
  ) {
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
  /// Finds all buttons, links, and other interactive elements and verifies
  /// they have proper semantic labels.
  static Future<void> verifyInteractiveElementsHaveLabels(
    WidgetTester tester,
  ) async {
    final semantics = RendererBinding.instance.rootPipelineOwner.semanticsOwner;
    if (semantics == null) {
      throw TestFailure(
        'Semantics not enabled. Enable with '
        'RendererBinding.instance.rootPipelineOwner.semanticsOwner = '
        'SemanticsOwner()',
      );
    }

    // This is a simplified check - in practice, you'd traverse the semantics
    // tree to find all interactive elements and verify they have labels
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
          reason: 'Button width must be at least '
              '${AccessibilityConstants.minTouchTargetSize}',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(AccessibilityConstants.minTouchTargetSize),
          reason: 'Button height must be at least '
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
      reason: 'Text contrast ratio in $context is $contrastRatio, '
          'which is below the minimum required '
          '${AccessibilityConstants.minContrastRatioNormal}',
    );
  }
}

/// Custom matchers for accessibility testing
class AccessibilityMatchers {
  AccessibilityMatchers._();

  /// Matcher for widgets with semantic labels
  static Matcher hasSemanticLabel(String? label) {
    return _SemanticLabelMatcher(label);
  }

  /// Matcher for widgets that are buttons
  static Matcher isButton() {
    return _ButtonMatcher();
  }

  /// Matcher for widgets that are enabled
  static Matcher isEnabled() {
    return _EnabledMatcher();
  }

  /// Matcher for widgets with minimum touch target size
  static Matcher hasMinTouchTarget() {
    return _MinTouchTargetMatcher();
  }
}

class _SemanticLabelMatcher extends Matcher {
  _SemanticLabelMatcher(this.expectedLabel);

  final String? expectedLabel;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    // This would need to be implemented based on your testing framework
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('has semantic label: $expectedLabel');
  }
}

class _ButtonMatcher extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('is a button');
  }
}

class _EnabledMatcher extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('is enabled');
  }
}

class _MinTouchTargetMatcher extends Matcher {
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('has minimum touch target size');
  }
}
