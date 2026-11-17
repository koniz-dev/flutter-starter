// Three pagination defects of OptimizedListView:
// - after a failed prefetch, every scroll tick near the bottom cleared the
//   inline error and called onLoadMore again;
// - with itemExtent set, the trailing error slot got one item's height and
//   overflowed;
// - an empty first page with hasMore showed "No items found" and never
//   loaded.

import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/l10n/app_localizations_en.dart';
import 'package:flutter_starter/shared/widgets/optimized_list_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: LocalizationService.supportedLocales,
  home: Scaffold(body: child),
);

final _l10n = AppLocalizationsEn();

void main() {
  testWidgets('a failed prefetch is not re-sent by scrolling, only by Retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        OptimizedListView<int>(
          items: List.generate(30, (i) => i),
          itemBuilder: (c, i, _) => SizedBox(height: 50, child: Text('$i')),
          hasMore: true,
          onLoadMore: () async {
            calls++;
            throw Exception('offline');
          },
        ),
      ),
    );
    await tester.drag(find.byType(Scrollable), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(calls, 1);

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(Scrollable), const Offset(0, -20));
      await tester.pumpAndSettle();
    }
    expect(calls, 1);
    expect(find.text('Exception: offline'), findsOneWidget);

    await tester.tap(find.text(_l10n.retry));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('with itemExtent the error slot renders without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OptimizedListView<int>(
          items: List.generate(3, (i) => i),
          itemBuilder: (c, i, _) => Text('$i'),
          itemExtent: 56,
          error: 'x',
          onRetry: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_l10n.retry), findsOneWidget);
    // The items keep their fixed extent.
    expect(tester.getSize(find.text('0').hitTestable()).height, lessThan(57));
  });

  testWidgets('an empty first page with hasMore offers Load More', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        OptimizedListView<int>(
          items: const [],
          itemBuilder: (c, i, _) => Text('item $i'),
          hasMore: true,
          onLoadMore: () async {
            calls++;
            return (<int>[1, 2], false);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_l10n.noItemsFound), findsNothing);

    await tester.tap(find.text(_l10n.loadMore));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('item 1'), findsOneWidget);
  });

  testWidgets('an empty list that cannot load still says no items', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OptimizedListView<int>(
          items: const [],
          itemBuilder: (c, i, _) => Text('$i'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_l10n.noItemsFound), findsOneWidget);
  });
}
