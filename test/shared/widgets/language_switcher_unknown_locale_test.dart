// Regression test for koniz-dev/flutter-starter#65, criterion 3.
//
// `LocaleNotifier.locale` is a public, unvalidated setter fed from storage, so
// a stale or hand-edited language code reaches the widgets. It used to hit a
// `firstWhere` with no `orElse` and throw `Bad state: No element`,
// red-screening the containing route.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required Locale storedLocale}) {
  final container = ProviderContainer(
    overrides: [
      currentLocaleProvider.overrideWith((ref) async => storedLocale),
    ],
  );
  container.read(localeStateProvider.notifier).locale = storedLocale;

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('LanguageSwitcherMenuItem with an unsupported stored locale', () {
    testWidgets('renders and falls back to the default locale', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LanguageSwitcherMenuItem(),
          // Not one of en/es/ar/vi.
          storedLocale: const Locale('de', 'DE'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LanguageSwitcherMenuItem), findsOneWidget);
      expect(
        find.text(SupportedLocale.fallback.displayName),
        findsOneWidget,
        reason: 'the subtitle should fall back to the default locale',
      );
    });

    testWidgets('a garbage language code does not throw', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LanguageSwitcherMenuItem(),
          storedLocale: const Locale('zz'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(SupportedLocale.fallback.displayName), findsOneWidget);
    });

    testWidgets('a supported locale still shows its own display name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LanguageSwitcherMenuItem(),
          storedLocale: const Locale('vi', 'VN'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(SupportedLocale.vi.displayName), findsOneWidget);
    });
  });
}
