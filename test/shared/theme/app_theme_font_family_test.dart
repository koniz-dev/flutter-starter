import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// What typeface the app actually resolves, per target platform.
///
/// A golden cannot answer this: `flutter test` renders every glyph with the
/// test font regardless of `fontFamily`, so a screenshot looks identical
/// whether the family resolves or not. The resolved `TextStyle` on the
/// `ThemeData` can answer it, and that is what these tests assert.
///
/// The tokens in `AppTypography` leave `fontFamily` null. `ThemeData` builds
/// its text theme as `defaultTextTheme.merge(textTheme)`, and `TextStyle.merge`
/// keeps the receiver's value where the argument is null, so the family that
/// survives is the one `Typography` picked for the platform.
void main() {
  /// The family Flutter's own Material typography uses per platform.
  ///
  /// Pinned as literals rather than read back from `Typography` so that an SDK
  /// change to these defaults shows up here as a visible diff.
  const expectedBody = <TargetPlatform, String>{
    TargetPlatform.android: 'Roboto',
    TargetPlatform.fuchsia: 'Roboto',
    TargetPlatform.iOS: 'CupertinoSystemText',
    TargetPlatform.macOS: '.AppleSystemUIFont',
    TargetPlatform.windows: 'Segoe UI',
    TargetPlatform.linux: 'Roboto',
  };

  const expectedDisplay = <TargetPlatform, String>{
    TargetPlatform.android: 'Roboto',
    TargetPlatform.fuchsia: 'Roboto',
    TargetPlatform.iOS: 'CupertinoSystemDisplay',
    TargetPlatform.macOS: '.AppleSystemUIFont',
    TargetPlatform.windows: 'Segoe UI',
    TargetPlatform.linux: 'Roboto',
  };

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('AppTheme inherits the platform font family', () {
    for (final platform in TargetPlatform.values) {
      test('${platform.name} resolves the platform default', () {
        debugDefaultTargetPlatformOverride = platform;

        for (final theme in <ThemeData>[
          AppTheme.lightTheme,
          AppTheme.darkTheme,
        ]) {
          expect(
            theme.textTheme.bodyLarge?.fontFamily,
            expectedBody[platform],
            reason: '${platform.name} bodyLarge',
          );
          expect(
            theme.textTheme.bodyMedium?.fontFamily,
            expectedBody[platform],
            reason: '${platform.name} bodyMedium',
          );
          expect(
            theme.textTheme.labelLarge?.fontFamily,
            expectedBody[platform],
            reason: '${platform.name} labelLarge',
          );
          expect(
            theme.textTheme.displayLarge?.fontFamily,
            expectedDisplay[platform],
            reason: '${platform.name} displayLarge',
          );
          expect(
            theme.textTheme.displayMedium?.fontFamily,
            expectedDisplay[platform],
            reason: '${platform.name} displayMedium',
          );
        }
      });

      test("${platform.name} matches Flutter's own Material default", () {
        debugDefaultTargetPlatformOverride = platform;

        final light = AppTheme.lightTheme;
        final defaults = Typography.material2021(
          platform: platform,
          colorScheme: light.colorScheme,
        ).black;

        expect(
          light.textTheme.bodyLarge?.fontFamily,
          defaults.bodyLarge?.fontFamily,
        );
        expect(
          light.textTheme.displayLarge?.fontFamily,
          defaults.displayLarge?.fontFamily,
        );
      });
    }

    test('apple targets no longer resolve to Roboto', () {
      // The regression this guards: the tokens used to pin Roboto on every
      // target. The repo bundles no font, and macOS ships none named Roboto,
      // so on Apple targets that name resolved to nothing and the engine fell
      // back silently while the theme still reported 'Roboto'.
      for (final platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          AppTheme.lightTheme.textTheme.bodyLarge?.fontFamily,
          isNot('Roboto'),
          reason: '${platform.name} must use its own system face',
        );
      }
    });

    test('the linux fallback chain is preserved', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        AppTheme.lightTheme.textTheme.bodyLarge?.fontFamilyFallback,
        containsAll(<String>['Ubuntu', 'DejaVu Sans']),
      );
    });
  });
}
