import 'dart:async';

import 'package:flutter_starter/shared/widgets/optimized_list_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _list(
  List<String> items,
  Future<(List<String>, bool)> Function() load,
) => MaterialApp(
  home: Scaffold(
    body: OptimizedListView<String>(
      items: items,
      hasMore: true,
      itemBuilder: (context, item, index) => Text(item),
      onLoadMore: load,
    ),
  ),
);

void main() {
  testWidgets('returned page renders and false hasMore stops pagination', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _list(['first'], () async {
        calls++;
        return (['next'], false);
      }),
    );
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('next'), findsOneWidget);
    expect(find.text('Load More'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
    'equal input rebuilds preserve pages; changed input resets them',
    (
      tester,
    ) async {
      Future<(List<String>, bool)> load() async => (['next'], false);
      await tester.pumpWidget(_list(['first'], load));
      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_list(['first'], load));
      expect(find.text('next'), findsOneWidget);
      expect(find.text('Load More'), findsNothing);
      await tester.pumpWidget(_list(['replacement'], load));
      expect(find.text('next'), findsNothing);
      expect(find.text('replacement'), findsOneWidget);
      expect(find.text('Load More'), findsOneWidget);
    },
  );

  testWidgets('reset ignores an old page while allowing the new load', (
    tester,
  ) async {
    final oldPage = Completer<(List<String>, bool)>();
    final newPage = Completer<(List<String>, bool)>();
    await tester.pumpWidget(_list(['old seed'], () => oldPage.future));
    await tester.tap(find.text('Load More'));
    await tester.pump();
    await tester.pumpWidget(_list(['new seed'], () => newPage.future));
    await tester.tap(find.text('Load More'));
    await tester.pump();
    oldPage.complete((['stale page'], false));
    await tester.pump();
    expect(find.text('stale page'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    newPage.complete((['current page'], false));
    await tester.pumpAndSettle();
    expect(find.text('current page'), findsOneWidget);
    expect(find.text('Load More'), findsNothing);
  });
}
