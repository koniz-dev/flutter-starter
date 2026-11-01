import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // On a phone the welcome heading wraps; centered with an edge inset, every
  // wrapped line stays off the screen edge like the hint below it.
  testWidgets('the welcome heading is centered and inset at phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeScreen));
    final welcome = find.text(AppLocalizations.of(context)!.welcome);
    expect(tester.widget<Text>(welcome).textAlign, TextAlign.center);
    expect(tester.getTopLeft(welcome).dx, greaterThanOrEqualTo(16));
    expect(tester.getTopRight(welcome).dx, lessThanOrEqualTo(390 - 16));
  });
}
