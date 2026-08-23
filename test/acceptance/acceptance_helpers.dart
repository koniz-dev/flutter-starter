/// Helpers for acceptance golden tests (see docs/issue-workflow.md).
///
/// Acceptance goldens exist to produce a committed PNG that a reviewer - human
/// or agent - can open and inspect as evidence for an issue's
/// `## Acceptance criteria`. They are NOT a CI gate: golden bytes depend on the
/// host renderer, so `dart_test.yaml` skips the `golden` tag by default and
/// ./scripts/test/run_acceptance.sh opts in explicitly.
///
/// READ THIS BEFORE TRUSTING A GOLDEN: `flutter test` renders text with the
/// Ahem test font, so every glyph is an opaque block. A golden proves widget
/// presence, position, size, colour, and overflow. It does NOT prove text
/// content or icon glyphs - assert those with `find.text()` / `find.byIcon()`
/// in the same test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Default capture surface. Wider than the 800x600 test default because Ahem
/// glyphs are far wider than real ones, so a narrow surface wraps and clips
/// text that the real app lays out on one line.
///
/// This reduces the problem but does not remove it. In Ahem every glyph is a
/// full em square, so the 51-character English `welcome` string at 28px
/// `headlineMedium` measures about 1428px and still wraps here, where a real
/// font needs roughly 714px and does not. Treat wrapped or clipped text in a
/// golden as a font artifact until you have checked the arithmetic - it is not
/// evidence of a layout bug.
const Size kAcceptanceSurface = Size(1200, 800);

/// Pumps [widget] inside the real app theme and localization delegates, on a
/// fixed surface, then settles.
///
/// Unlike `test/helpers/pump_app.dart` this applies [AppTheme] rather than
/// `ThemeData.light()`, so colours in the captured PNG match the shipped app.
Future<void> pumpAcceptance(
  WidgetTester tester,
  Widget widget, {
  dynamic overrides,
  Size surface = kAcceptanceSurface,
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      // `Override` is not exported by flutter_riverpod (see
      // test/helpers/pump_app.dart, which uses the same workaround). When
      // `overrides` is supplied it is already a List<Override>.
      // ignore: argument_type_not_assignable
      overrides: overrides ?? <Never>[],
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: widget,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Captures [finder] to `goldens/<name>.png`, relative to the test file.
///
/// Regenerate with `./scripts/test/run_acceptance.sh --update`.
Future<void> captureAcceptanceGolden(Finder finder, String name) {
  return expectLater(finder, matchesGoldenFile('goldens/$name.png'));
}
