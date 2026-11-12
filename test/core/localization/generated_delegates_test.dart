import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('generated delegates serve standalone UI for $locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              expect(AppLocalizations.of(context), isNotNull);
              expect(
                MaterialLocalizations.of(context).okButtonLabel,
                isNotEmpty,
              );
              expect(
                CupertinoLocalizations.of(context).copyButtonLabel,
                isNotEmpty,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
