import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// koniz-dev/flutter-starter#513 (split from #352): HomeScreen rendered its
// 'Add screens under lib/features/.' hint as a literal, so it read in English
// under every locale.

const _english = 'Add screens under lib/features/.';

Future<void> _pump(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const [Locale('es'), Locale('vi')]) {
    testWidgets('criteria 1-2 (${locale.languageCode}): the hint is the '
        'localized string, not the English literal', (tester) async {
      await _pump(tester, locale);

      expect(
        find.text(lookupAppLocalizations(locale).homeAddScreensHint),
        findsOneWidget,
      );
      expect(find.text(_english), findsNothing);
    });
  }

  testWidgets('under en the hint keeps its wording', (tester) async {
    await _pump(tester, const Locale('en'));

    expect(find.text(_english), findsOneWidget);
  });
}
