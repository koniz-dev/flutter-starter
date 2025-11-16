import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessibilityHelpers', () {
    group('getContrastRatio', () {
      test('returns high contrast for black on white', () {
        final ratio = AccessibilityHelpers.getContrastRatio(
          Colors.black,
          Colors.white,
        );
        expect(ratio, greaterThan(15.0));
      });

      test('returns low contrast for similar colors', () {
        final ratio = AccessibilityHelpers.getContrastRatio(
          Colors.grey,
          Colors.grey.shade700,
        );
        expect(ratio, lessThan(5.0));
      });

      test('returns 1.0 for same color', () {
        final ratio = AccessibilityHelpers.getContrastRatio(
          Colors.black,
          Colors.black,
        );
        expect(ratio, closeTo(1.0, 0.01));
      });
    });

    group('meetsContrastRatioAA', () {
      test('returns true for black on white', () {
        expect(
          AccessibilityHelpers.meetsContrastRatioAA(
            Colors.black,
            Colors.white,
          ),
          isTrue,
        );
      });

      test('returns false for low contrast combinations', () {
        expect(
          AccessibilityHelpers.meetsContrastRatioAA(
            Colors.grey.shade400,
            Colors.grey.shade500,
          ),
          isFalse,
        );
      });
    });

    group('meetsContrastRatioAALarge', () {
      test('returns true for black on white', () {
        expect(
          AccessibilityHelpers.meetsContrastRatioAALarge(
            Colors.black,
            Colors.white,
          ),
          isTrue,
        );
      });

      test('allows lower contrast for large text', () {
        // Large text has lower requirements (3:1 vs 4.5:1)
        final ratio = AccessibilityHelpers.getContrastRatio(
          Colors.grey.shade600,
          Colors.white,
        );
        if (ratio >= AccessibilityConstants.minContrastRatioLarge) {
          expect(
            AccessibilityHelpers.meetsContrastRatioAALarge(
              Colors.grey.shade600,
              Colors.white,
            ),
            isTrue,
          );
        }
      });
    });

    group('getAccessibleTextColor', () {
      test('returns black for light backgrounds', () {
        final color = AccessibilityHelpers.getAccessibleTextColor(
          Colors.white,
        );
        expect(color, Colors.black);
      });

      test('returns white for dark backgrounds', () {
        final color = AccessibilityHelpers.getAccessibleTextColor(
          Colors.black,
        );
        expect(color, Colors.white);
      });
    });

    group('getButtonSemanticLabel', () {
      test('returns base label when no state provided', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel('Submit');
        expect(label, 'Submit');
      });

      test('includes loading state', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Submit',
          isLoading: true,
        );
        expect(label, 'Loading, Submit');
      });

      test('includes disabled state', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Submit',
          isEnabled: false,
        );
        expect(label, 'Submit, Disabled');
      });

      test('includes all states', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Submit',
          isLoading: true,
          isEnabled: false,
          additionalInfo: 'Form validation',
        );
        expect(label, 'Loading, Submit, Disabled, Form validation');
      });
    });

    group('getProgressSemanticValue', () {
      test('formats percentage correctly', () {
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0.5),
          '50 percent',
        );
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0),
          '0 percent',
        );
        expect(
          AccessibilityHelpers.getProgressSemanticValue(1),
          '100 percent',
        );
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0.123),
          '12 percent',
        );
      });
    });
  });
}
