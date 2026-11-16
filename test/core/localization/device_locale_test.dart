// With no stored language choice the app follows the device language.
//
// LocaleNotifier.build() and LocalizationService.getCurrentLocale() both
// returned the fixed default (en_US) when nothing was stored, and
// MaterialApp.router always received that non-null locale, so a device set to
// Vietnamese opened a starter that ships a Vietnamese ARB in English.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));
final AppLocalizations _es = lookupAppLocalizations(const Locale('es'));

void main() {
  /// Pumps the real [MyApp] with [stored] as the persisted preferences and
  /// [device] as the platform's preferred locales, the way main() would
  /// after startup.
  Future<ProviderContainer> pumpRealApp(
    WidgetTester tester, {
    required List<Locale> device,
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    tester.platformDispatcher.localesTestValue = device;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    return container;
  }

  group('runtime system locale', () {
    testWidgets(
      'runtime locale refreshes a fallback captured before mounting',
      (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.platformDispatcher.localesTestValue = const [Locale('en')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.runAsync(
          () => container.read(currentLocaleProvider.future),
        );
        expect(container.read(localeStateProvider).languageCode, 'en');
        tester.platformDispatcher.localesTestValue = const [Locale('vi')];
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.locale?.languageCode, 'vi');
      },
    );

    for (final corrupt in [false, true]) {
      testWidgets(
        'runtime locale follows platform changes (corrupt=$corrupt)',
        (
          tester,
        ) async {
          await pumpRealApp(
            tester,
            device: const [Locale('en', 'US')],
            stored: corrupt ? const {'language': 42} : const {},
          );
          for (final language in ['vi', 'es', 'ar', 'ja']) {
            tester.platformDispatcher.localesTestValue = [Locale(language)];
            await tester.pumpAndSettle();
            final expected = language == 'ja' ? 'en' : language;
            final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
            expect(app.locale?.languageCode, expected);
            final l10n = lookupAppLocalizations(Locale(expected));
            expect(find.text(l10n.welcome), findsOneWidget);
            expect(
              Directionality.of(tester.element(find.text(l10n.welcome))),
              expected == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            );
          }
        },
      );
    }

    testWidgets('runtime locale keeps a stored choice', (tester) async {
      await pumpRealApp(
        tester,
        device: const [Locale('vi')],
        stored: const {'language': 'es'},
      );
      tester.platformDispatcher.localesTestValue = const [Locale('ar')];
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale?.languageCode, 'es');
      expect(find.text(_es.welcome), findsOneWidget);
    });

    testWidgets('runtime locale keeps an in-memory choice', (tester) async {
      final container = await pumpRealApp(
        tester,
        device: const [Locale('en')],
      );
      container.read(localeStateProvider.notifier).locale = const Locale('es');
      await tester.pumpAndSettle();
      tester.platformDispatcher.localesTestValue = const [Locale('vi')];
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale?.languageCode, 'es');
      expect(find.text(_es.welcome), findsOneWidget);
    });
  });

  group('criterion 1: an empty preference follows the device', () {
    testWidgets('a vi_VN device renders the home screen in Vietnamese', (
      tester,
    ) async {
      await pumpRealApp(tester, device: const [Locale('vi', 'VN')]);

      expect(find.text(_vi.welcome), findsOneWidget);
      expect(find.text(_en.welcome), findsNothing);
    });

    testWidgets('the first supported language in the device list wins', (
      tester,
    ) async {
      await pumpRealApp(
        tester,
        device: const [Locale('fr', 'FR'), Locale('es', 'ES')],
      );

      expect(find.text(_es.welcome), findsOneWidget);
    });
  });

  group('criterion 2: a stored preference still wins', () {
    testWidgets('stored es on a vi device renders Spanish', (tester) async {
      await pumpRealApp(
        tester,
        device: const [Locale('vi', 'VN')],
        stored: const {'language': 'es'},
      );

      expect(find.text(_es.welcome), findsOneWidget);
      expect(find.text(_vi.welcome), findsNothing);
    });
  });

  group('criterion 3: an unsupported device language falls back', () {
    testWidgets('a ja_JP device renders the fallback, English', (
      tester,
    ) async {
      await pumpRealApp(tester, device: const [Locale('ja', 'JP')]);

      expect(SupportedLocale.fallback, SupportedLocale.en);
      expect(find.text(_en.welcome), findsOneWidget);
    });

    test('deviceLocale resolves against the supported list', () {
      expect(
        LocalizationService.deviceLocale(const [Locale('ar', 'EG')]),
        SupportedLocale.ar.locale,
      );
      expect(
        LocalizationService.deviceLocale(const [Locale('ja')]),
        LocalizationService.defaultLocale,
      );
      expect(
        LocalizationService.deviceLocale(const []),
        LocalizationService.defaultLocale,
      );
    });
  });
}
