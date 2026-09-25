/// WCAG AA contrast gate for every foreground/background pair the shipped
/// themes define.
///
/// Ratios are computed with the repository's own
/// `AccessibilityHelpers.getContrastRatio` and checked against
/// `AccessibilityConstants`, so the palette and the accessibility constants
/// cannot drift apart silently.
///
/// Each pair pins its measured ratio as well as the AA floor. That is
/// deliberate: changing a palette value fails this suite even when the new
/// value still clears AA, which forces the change to be re-measured rather than
/// assumed. Update the `ratio` argument with the number the failure reports.
///
/// Large text: WCAG 2.1 treats 18pt (24 logical px) regular or 14pt (18.66 px)
/// bold as large and relaxes the floor to 3:1. Only `displayLarge` (32 px bold)
/// and `displayMedium` (24 px w600) qualify here, and both clear the stricter
/// 4.5:1 anyway, so **every text pair below is held to
/// `minContrastRatioNormal`**. In particular `labelLarge` is 14 px w600 -
/// 10.5pt bold - not large text, so its 3:1 exemption does not apply.
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/core/accessibility/accessibility_helpers.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// A foreground/background pair with the floor it has to clear.
class _Pair {
  const _Pair(
    this.name,
    this.foreground,
    this.background, {
    required this.ratio,
    this.minimum = AccessibilityConstants.minContrastRatioNormal,
  });

  final String name;
  final Color foreground;
  final Color background;

  /// Measured ratio, pinned so a palette edit has to restate it.
  final double ratio;

  /// Floor this pair must clear.
  final double minimum;
}

/// Resolves a button theme's colours, which are `WidgetStateProperty`s.
///
/// Called while the pair list is built, outside any test, so it throws rather
/// than calling `expect`.
Color _resolve(WidgetStateProperty<Color?>? property, String what) {
  final color = property?.resolve(<WidgetState>{});
  if (color == null) {
    throw StateError('$what is unset, so its contrast cannot be checked');
  }
  return color;
}

void main() {
  final light = AppTheme.lightTheme;
  final dark = AppTheme.darkTheme;

  final lightButton = light.elevatedButtonTheme.style!;
  final darkButton = dark.elevatedButtonTheme.style!;

  final lightPairs = <_Pair>[
    _Pair(
      'onPrimary on primary',
      light.colorScheme.onPrimary,
      light.colorScheme.primary,
      ratio: 5.22,
    ),
    _Pair(
      'onSecondary on secondary',
      light.colorScheme.onSecondary,
      light.colorScheme.secondary,
      ratio: 4.69,
    ),
    _Pair(
      'onSurface on surface',
      light.colorScheme.onSurface,
      light.colorScheme.surface,
      ratio: 15.43,
    ),
    _Pair(
      'onError on error',
      light.colorScheme.onError,
      light.colorScheme.error,
      ratio: 4.53,
    ),
    _Pair(
      'displayLarge on background',
      light.textTheme.displayLarge!.color!,
      light.scaffoldBackgroundColor,
      ratio: 14.63,
    ),
    _Pair(
      'displayMedium on background',
      light.textTheme.displayMedium!.color!,
      light.scaffoldBackgroundColor,
      ratio: 14.63,
    ),
    _Pair(
      'bodyLarge on background',
      light.textTheme.bodyLarge!.color!,
      light.scaffoldBackgroundColor,
      ratio: 14.63,
    ),
    _Pair(
      'bodyMedium on background',
      light.textTheme.bodyMedium!.color!,
      light.scaffoldBackgroundColor,
      ratio: 5.89,
    ),
    _Pair(
      'labelLarge on background',
      light.textTheme.labelLarge!.color!,
      light.scaffoldBackgroundColor,
      ratio: 14.63,
    ),
    _Pair(
      'bodyMedium on surface',
      light.textTheme.bodyMedium!.color!,
      light.colorScheme.surface,
      ratio: 6.21,
    ),
    _Pair(
      'labelLarge on surface',
      light.textTheme.labelLarge!.color!,
      light.colorScheme.surface,
      ratio: 15.43,
    ),
    _Pair(
      'appBar foreground on appBar background',
      light.appBarTheme.foregroundColor!,
      light.appBarTheme.backgroundColor!,
      ratio: 5.22,
    ),
    _Pair(
      'ElevatedButton foreground on its background',
      _resolve(lightButton.foregroundColor, 'light button foreground'),
      _resolve(lightButton.backgroundColor, 'light button background'),
      ratio: 5.22,
    ),
  ];

  final darkPairs = <_Pair>[
    _Pair(
      'onPrimary on primary',
      dark.colorScheme.onPrimary,
      dark.colorScheme.primary,
      ratio: 5.22,
    ),
    _Pair(
      'onSecondary on secondary',
      dark.colorScheme.onSecondary,
      dark.colorScheme.secondary,
      ratio: 4.69,
    ),
    _Pair(
      'onSurface on surface',
      dark.colorScheme.onSurface,
      dark.colorScheme.surface,
      ratio: 16.67,
    ),
    _Pair(
      'onError on error',
      dark.colorScheme.onError,
      dark.colorScheme.error,
      ratio: 4.53,
    ),
    _Pair(
      'displayLarge on background',
      dark.textTheme.displayLarge!.color!,
      dark.scaffoldBackgroundColor,
      ratio: 18.73,
    ),
    _Pair(
      'displayMedium on background',
      dark.textTheme.displayMedium!.color!,
      dark.scaffoldBackgroundColor,
      ratio: 18.73,
    ),
    _Pair(
      'bodyLarge on background',
      dark.textTheme.bodyLarge!.color!,
      dark.scaffoldBackgroundColor,
      ratio: 18.73,
    ),
    _Pair(
      'bodyMedium on background',
      dark.textTheme.bodyMedium!.color!,
      dark.scaffoldBackgroundColor,
      ratio: 9.03,
    ),
    _Pair(
      'labelLarge on background',
      dark.textTheme.labelLarge!.color!,
      dark.scaffoldBackgroundColor,
      ratio: 18.73,
    ),
    _Pair(
      'bodyMedium on surface',
      dark.textTheme.bodyMedium!.color!,
      dark.colorScheme.surface,
      ratio: 8.03,
    ),
    _Pair(
      'appBar foreground on appBar background',
      dark.appBarTheme.foregroundColor!,
      dark.appBarTheme.backgroundColor!,
      ratio: 16.67,
    ),
    _Pair(
      'ElevatedButton foreground on its background',
      _resolve(darkButton.foregroundColor, 'dark button foreground'),
      _resolve(darkButton.backgroundColor, 'dark button background'),
      ratio: 5.22,
    ),
  ];

  // Status tokens are exposed through AppDesignTokens, so they carry the same
  // obligation as the theme's own pairs. Each states how it is used.
  const statusPairs = <_Pair>[
    _Pair(
      'textInverse on the success fill',
      AppColors.textInverse,
      AppColors.success,
      ratio: 5.14,
    ),
    _Pair(
      'textPrimary on the warning fill',
      AppColors.textPrimary,
      AppColors.warning,
      ratio: 9.46,
    ),
    _Pair(
      'textInverse on the info fill',
      AppColors.textInverse,
      AppColors.info,
      ratio: 5.02,
    ),
    _Pair(
      'success as a foreground on background',
      AppColors.success,
      AppColors.background,
      ratio: 4.87,
    ),
    _Pair(
      'success as a foreground on surface',
      AppColors.success,
      AppColors.surface,
      ratio: 5.14,
    ),
    _Pair(
      'info as a foreground on background',
      AppColors.info,
      AppColors.background,
      ratio: 4.77,
    ),
  ];

  // WCAG 2.1 1.4.11 asks 3:1 of non-text UI (focus rings, borders, icons).
  // minContrastRatioLarge is the same 3:1 number.
  final nonTextPairs = <_Pair>[
    _Pair(
      'primary as a focus ring on the dark surface',
      AppColors.primary,
      dark.colorScheme.surface,
      ratio: 3.19,
      minimum: AccessibilityConstants.minContrastRatioLarge,
    ),
    _Pair(
      'primary as a focus ring on the dark background',
      AppColors.primary,
      dark.scaffoldBackgroundColor,
      ratio: 3.59,
      minimum: AccessibilityConstants.minContrastRatioLarge,
    ),
    _Pair(
      'success as an icon on the dark surface',
      AppColors.success,
      dark.colorScheme.surface,
      ratio: 3.25,
      minimum: AccessibilityConstants.minContrastRatioLarge,
    ),
  ];

  void verify(String theme, List<_Pair> pairs) {
    group(theme, () {
      for (final pair in pairs) {
        test('${pair.name} meets ${pair.minimum}:1', () {
          // getContrastRatio composites a translucent foreground over the
          // background and rejects a translucent background outright (#82), so
          // these assertions are no longer load-bearing for correctness. They
          // stay as a palette rule: a theme token that ships translucent hides
          // its real contrast behind whatever happens to be painted below it,
          // and the pinned ratios below would then only hold for this one
          // backdrop.
          expect(
            pair.foreground.a,
            1.0,
            reason: '${pair.name}: foreground must be opaque',
          );
          expect(
            pair.background.a,
            1.0,
            reason: '${pair.name}: background must be opaque',
          );

          final ratio = AccessibilityHelpers.getContrastRatio(
            pair.foreground,
            pair.background,
          );

          expect(
            ratio,
            greaterThanOrEqualTo(pair.minimum),
            reason:
                '$theme ${pair.name}: '
                '${pair.foreground} on ${pair.background} is '
                '${ratio.toStringAsFixed(2)}:1, below ${pair.minimum}:1',
          );
          expect(
            ratio,
            closeTo(pair.ratio, 0.01),
            reason:
                '$theme ${pair.name}: measured ${ratio.toStringAsFixed(2)}:1 '
                'but the test pins ${pair.ratio}:1 - a palette value changed',
          );
        });
      }
    });
  }

  group('theme contrast', () {
    verify('light theme', lightPairs);
    verify('dark theme', darkPairs);
    verify('status tokens', statusPairs);
    verify('non-text tokens', nonTextPairs);

    // The defect this suite was written for: labelLarge shipped as #FFFFFF in
    // the light TextTheme, 1.05:1 on the #F8F9FA scaffold - invisible.
    test('light labelLarge is not white on the near-white scaffold', () {
      final labelColor = AppTheme.lightTheme.textTheme.labelLarge!.color!;

      expect(labelColor, isNot(AppColors.textInverse));
      expect(
        AccessibilityHelpers.meetsContrastRatioAA(
          labelColor,
          AppTheme.lightTheme.scaffoldBackgroundColor,
        ),
        isTrue,
      );
    });

    test('secondary and textSecondary are no longer the same colour', () {
      // They were both #6C757D, which forced one of them to fail: a fill needs
      // to be light enough to carry dark text, a text colour dark enough to sit
      // on a light background.
      expect(AppColors.secondary, isNot(AppColors.textSecondary));
    });
  });
}
