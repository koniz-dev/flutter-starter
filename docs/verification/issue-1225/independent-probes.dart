import 'package:cupertino_ui/cupertino_ui.dart' as c;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as m;
import 'package:patrol_finders/patrol_finders.dart';

final labelProvider = Provider((ref) => 'consumer ready');

class Probe extends ConsumerWidget {
  const Probe({super.key});
  @override
  m.Widget build(m.BuildContext context, WidgetRef ref) {
    expect(m.Theme.of(context).brightness, m.Brightness.dark);
    expect(m.MaterialLocalizations.of(context).okButtonLabel, isNotEmpty);
    expect(c.CupertinoLocalizations.of(context).copyButtonLabel, isNotEmpty);
    expect(AppLocalizations.of(context), isNotNull);
    return m.Column(children: [
      m.Text(ref.watch(labelProvider)),
      const m.TextField(key: m.ValueKey('review-input')),
      c.CupertinoButton(onPressed: () {}, child: const m.Text('cupertino action')),
    ]);
  }
}

void main() {
  test('generated list has standalone delegate identities', () {
    final delegates = AppLocalizations.localizationsDelegates;
    expect(delegates, contains(m.GlobalMaterialLocalizations.delegate));
    expect(delegates, contains(c.GlobalCupertinoLocalizations.delegate));
    expect(delegates.first, same(AppLocalizations.delegate));
  });
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Riverpod and Patrol act on standalone widgets: $locale', (tester) async {
      await tester.pumpWidget(ProviderScope(child: m.MaterialApp(
        theme: m.ThemeData.dark(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const m.Scaffold(body: Probe()),
      )));
      await tester.pumpAndSettle();
      final patrol = PatrolTester(tester: tester, config: const PatrolTesterConfig());
      expect(patrol(m.TextField), findsOneWidget);
      await patrol(m.TextField).enterText('review@example.invalid');
      expect(find.text('review@example.invalid'), findsOneWidget);
      expect(find.text('consumer ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const m.SizedBox.shrink());
    });
  }
}
