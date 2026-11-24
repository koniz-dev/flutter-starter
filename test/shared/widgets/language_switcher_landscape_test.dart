import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalizationService extends Mock implements LocalizationService {}

// Phone landscape surfaces: the four radio tiles, the title and the actions
// do not fit their height, so the dialog has to scroll rather than overflow.
const _surfaces = [Size(844, 390), Size(800, 360)];
const _textScales = [1.0, 2.0];

final _switchers = <({String name, Widget widget, Finder opener})>[
  (
    name: 'LanguageSwitcher',
    widget: const LanguageSwitcher(),
    opener: find.byType(LanguageSwitcher),
  ),
  (
    name: 'LanguageSwitcherMenuItem',
    widget: const LanguageSwitcherMenuItem(),
    opener: find.byType(LanguageSwitcherMenuItem),
  ),
];

Future<_MockLocalizationService> _pumpSwitcher(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  required double textScale,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final service = _MockLocalizationService();
  when(() => service.setCurrentLocale(any())).thenAnswer((_) async => true);
  when(service.getCurrentLocale).thenAnswer((_) async => const Locale('en'));

  final container = ProviderContainer(
    overrides: [
      localizationServiceProvider.overrideWithValue(service),
      currentLocaleProvider.overrideWith((ref) async => const Locale('en')),
    ],
  );
  addTearDown(container.dispose);
  container.read(localeStateProvider.notifier).state = const Locale('en');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  return service;
}

Future<void> _openDialog(WidgetTester tester, Finder opener) async {
  await tester.tap(opener);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  // A RenderFlex overflow is reported through FlutterError and would fail
  // the test on its own; asserting here names the failure.
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() => registerFallbackValue(const Locale('en')));

  for (final switcher in _switchers) {
    for (final size in _surfaces) {
      for (final textScale in _textScales) {
        final label =
            '${switcher.name} at ${size.width.toInt()}x'
            '${size.height.toInt()} x$textScale';

        testWidgets('$label: the dialog fits and Cancel is reachable', (
          tester,
        ) async {
          await _pumpSwitcher(
            tester,
            child: switcher.widget,
            size: size,
            textScale: textScale,
          );
          await _openDialog(tester, switcher.opener);

          final cancel = find.widgetWithText(TextButton, 'Cancel');
          await tester.ensureVisible(cancel);
          await tester.pumpAndSettle();
          await tester.tap(cancel);
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('$label: the last locale scrolls into reach and applies', (
          tester,
        ) async {
          final service = await _pumpSwitcher(
            tester,
            child: switcher.widget,
            size: size,
            textScale: textScale,
          );
          await _openDialog(tester, switcher.opener);

          final last = SupportedLocale.values.last;
          final tile = find.widgetWithText(
            RadioListTile<Locale>,
            last.displayName,
          );
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          await tester.tap(tile);
          await tester.pumpAndSettle();

          verify(() => service.setCurrentLocale(last.locale)).called(1);
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
