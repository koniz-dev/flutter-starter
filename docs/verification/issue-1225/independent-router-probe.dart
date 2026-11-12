import 'package:cupertino_ui/cupertino_ui.dart' as c;
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' as m;

void main() {
  testWidgets('GoRouter uses modern pages and locale delegates on navigation and errors', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const m.Scaffold(body: m.Text('root'))),
      GoRoute(path: '/next', builder: (context, state) => m.Scaffold(body: m.Builder(builder: (context) {
        expect(m.Theme.of(context).brightness, m.Brightness.dark);
        expect(m.MaterialLocalizations.of(context).okButtonLabel, isNotEmpty);
        expect(c.CupertinoLocalizations.of(context).copyButtonLabel, isNotEmpty);
        return const m.Text('next');
      }))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(m.MaterialApp.router(
      theme: m.ThemeData.dark(),
      routerConfig: router,
      locale: const m.Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ));
    await tester.pumpAndSettle();
    router.go('/next');
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
    router.go('/missing');
    await tester.pumpAndSettle();
    expect(find.text('Page Not Found'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const m.SizedBox.shrink());
  });
}
