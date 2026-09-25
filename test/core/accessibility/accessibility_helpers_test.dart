import 'package:flutter/material.dart';
import 'package:flutter_starter/core/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/core/accessibility/accessibility_helpers.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final vi = lookupAppLocalizations(const Locale('vi'));

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

    // The WCAG formula has no alpha term. Before this group existed the helper
    // simply dropped `color.a`, so a 70% white scored the same as #FFFFFF.
    // The chosen semantics: composite a translucent foreground over the
    // supplied background, reject a translucent background outright.
    group('alpha channel', () {
      // Colors.white70 (0xB3FFFFFF) on the dark scaffold. Compositing gives
      // 0.70196 * 1.0 + 0.29804 * (18/255) = 0.72299 per channel (#B8B8B8),
      // whose luminance is 0.48157 against the scaffold's 0.00606:
      // (0.48157 + 0.05) / (0.00606 + 0.05) = 9.48:1.
      const white70 = Color(0xB3FFFFFF);
      const darkScaffold = Color(0xFF121212);

      test('composites a translucent foreground over the background', () {
        final ratio = AccessibilityHelpers.getContrastRatio(
          white70,
          darkScaffold,
        );

        expect(ratio, closeTo(9.48, 0.01));
      });

      test('does not score a translucent colour as if it were opaque', () {
        final translucent = AccessibilityHelpers.getContrastRatio(
          white70,
          darkScaffold,
        );
        final opaque = AccessibilityHelpers.getContrastRatio(
          const Color(0xFFFFFFFF),
          darkScaffold,
        );

        // 18.73:1 is what the old implementation returned for both.
        expect(opaque, closeTo(18.73, 0.01));
        expect(translucent, lessThan(opaque));
      });

      test('white70 clears AA on the dark scaffold, white24 does not', () {
        // Two sides of the same coin: compositing must be able to fail a pair,
        // not just lower a number.
        expect(
          AccessibilityHelpers.meetsContrastRatioAA(white70, darkScaffold),
          isTrue,
        );
        expect(
          AccessibilityHelpers.meetsContrastRatioAA(
            const Color(0x3DFFFFFF),
            darkScaffold,
          ),
          isFalse,
        );
      });

      test('AAA follows the composited ratio, not the opaque one', () {
        // Opaque white on #121212 is 18.73:1 and clears AAA comfortably; the
        // same white at 50% composites to 5.35:1, below the 7:1 AAA floor.
        expect(
          AccessibilityHelpers.meetsContrastRatioAAA(
            const Color(0xFFFFFFFF),
            darkScaffold,
          ),
          isTrue,
        );
        expect(
          AccessibilityHelpers.meetsContrastRatioAAA(
            const Color(0x80FFFFFF),
            darkScaffold,
          ),
          isFalse,
        );
      });

      test('a fully transparent foreground is the background', () {
        final ratio = AccessibilityHelpers.getContrastRatio(
          const Color(0x00FFFFFF),
          darkScaffold,
        );

        expect(ratio, closeTo(1.0, 0.0001));
      });

      test('black54 on white composites instead of scoring 21:1', () {
        final ratio = AccessibilityHelpers.getContrastRatio(
          const Color(0x8A000000),
          const Color(0xFFFFFFFF),
        );

        expect(ratio, closeTo(4.61, 0.01));
        expect(ratio, lessThan(21.0));
      });

      test('rejects a translucent background', () {
        expect(
          () => AccessibilityHelpers.getContrastRatio(
            const Color(0xFFFFFFFF),
            const Color(0x80121212),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects a translucent background through the AA/AAA wrappers', () {
        const translucentBackground = Color(0x80121212);

        expect(
          () => AccessibilityHelpers.meetsContrastRatioAA(
            const Color(0xFFFFFFFF),
            translucentBackground,
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => AccessibilityHelpers.meetsContrastRatioAALarge(
            const Color(0xFFFFFFFF),
            translucentBackground,
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => AccessibilityHelpers.meetsContrastRatioAAA(
            const Color(0xFFFFFFFF),
            translucentBackground,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // Criterion 2 of issue #82: honouring alpha must not re-baseline the
    // palette. These are the colours a real renderer painted, sampled out of
    // the committed goldens in docs/verification/issue-55/pixel-sample.log,
    // with the ratios that log recorded. They are literals rather than theme
    // lookups on purpose - this pins the *helper*, so it fails even if the
    // palette is edited at the same time.
    group('opaque colours are scored exactly as before', () {
      const pinned = <String, (Color, Color, double)>{
        'light bodyLarge/labelLarge #212529 on the #F8F9FA scaffold': (
          Color(0xFF212529),
          Color(0xFFF8F9FA),
          14.63,
        ),
        'light bodyMedium #5A6268 on the #F8F9FA scaffold': (
          Color(0xFF5A6268),
          Color(0xFFF8F9FA),
          5.89,
        ),
        'button label #FFFFFF on the #0069D9 fill': (
          Color(0xFFFFFFFF),
          Color(0xFF0069D9),
          5.22,
        ),
        'dark bodyMedium #ADB5BD on the #121212 scaffold': (
          Color(0xFFADB5BD),
          Color(0xFF121212),
          9.03,
        ),
        'dark appBar label #FFFFFF on the #1E1E1E bar': (
          Color(0xFFFFFFFF),
          Color(0xFF1E1E1E),
          16.67,
        ),
      };

      pinned.forEach((name, pair) {
        final (foreground, background, expected) = pair;
        test('$name is $expected:1', () {
          expect(foreground.a, 1.0);
          expect(background.a, 1.0);
          expect(
            AccessibilityHelpers.getContrastRatio(foreground, background),
            closeTo(expected, 0.005),
          );
        });
      });
    });

    group('meetsContrastRatioAA', () {
      test('returns true for black on white', () {
        expect(
          AccessibilityHelpers.meetsContrastRatioAA(Colors.black, Colors.white),
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
        final color = AccessibilityHelpers.getAccessibleTextColor(Colors.white);
        expect(color, Colors.black);
      });

      test('returns white for dark backgrounds', () {
        final color = AccessibilityHelpers.getAccessibleTextColor(Colors.black);
        expect(color, Colors.white);
      });
    });

    group('getButtonSemanticLabel', () {
      test('returns base label when no state provided', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Submit',
          l10n: en,
        );
        expect(label, 'Submit');
      });

      test('includes loading state', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Submit',
          l10n: en,
          isLoading: true,
        );
        expect(label, 'Loading, Submit');
      });

      test('includes disabled state', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Submit',
          l10n: en,
          isEnabled: false,
        );
        expect(label, 'Submit, Disabled');
      });

      test('includes all states', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Submit',
          l10n: en,
          isLoading: true,
          isEnabled: false,
          additionalInfo: 'Form validation',
        );
        expect(label, 'Loading, Submit, Disabled, Form validation');
      });

      test('state words follow the supplied locale', () {
        final label = AccessibilityHelpers.getButtonSemanticLabel(
          'Gui',
          l10n: vi,
          isLoading: true,
          isEnabled: false,
        );
        expect(label, '${vi.stateLoading}, Gui, ${vi.stateDisabled}');
        expect(label, isNot(contains('Loading')));
        expect(label, isNot(contains('Disabled')));
      });
    });

    group('getProgressSemanticValue', () {
      test('formats percentage correctly', () {
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0.5, l10n: en),
          '50 percent',
        );
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0, l10n: en),
          '0 percent',
        );
        expect(
          AccessibilityHelpers.getProgressSemanticValue(1, l10n: en),
          '100 percent',
        );
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0.123, l10n: en),
          '12 percent',
        );
      });

      test('follows the supplied locale', () {
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0.5, l10n: vi),
          vi.percentValue(50),
        );
        expect(
          AccessibilityHelpers.getProgressSemanticValue(0.5, l10n: vi),
          isNot(contains('percent')),
        );
      });
    });
  });
}
