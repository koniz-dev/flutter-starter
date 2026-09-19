// Regression tests for koniz-dev/flutter-starter#65, criterion 2.
//
// An empty list must not look the same whether the load succeeded with no
// results or failed outright.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/optimized_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: LocalizationService.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('OptimizedListView empty vs failed', () {
    testWidgets('empty + error renders the error and a retry, not the empty '
        'state', (tester) async {
      var retries = 0;

      await tester.pumpWidget(
        _wrap(
          OptimizedListView<String>(
            items: const [],
            error: 'BOOM network failed',
            onRetry: () => retries++,
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      expect(find.text('BOOM network failed'), findsOneWidget);
      expect(find.text(en.retry), findsOneWidget);
      expect(find.text(en.noItemsFound), findsNothing);

      await tester.tap(find.text(en.retry));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('empty + error still shows the error with no onRetry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OptimizedListView<String>(
            items: const [],
            error: 'BOOM network failed',
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      expect(find.text('BOOM network failed'), findsOneWidget);
      expect(find.text(en.noItemsFound), findsNothing);
    });

    testWidgets('empty without an error still shows the empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OptimizedListView<String>(
            items: const [],
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      expect(find.text(en.noItemsFound), findsOneWidget);
    });

    testWidgets('non-empty + error shows the error below the items', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OptimizedListView<String>(
            items: const ['Item 1'],
            error: 'BOOM network failed',
            onRetry: () {},
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('BOOM network failed'), findsOneWidget);
      expect(find.text(en.retry), findsOneWidget);
    });
  });

  group('OptimizedListView prefetch failure', () {
    testWidgets('a throwing prefetch surfaces inline and to the parent', (
      tester,
    ) async {
      Object? reported;
      final items = List<String>.generate(40, (i) => 'Item $i');

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 400,
            child: OptimizedListView<String>(
              items: items,
              hasMore: true,
              onLoadMore: () async => throw StateError('PREFETCH BOOM'),
              onLoadMoreError: (error, stackTrace) => reported = error,
              itemBuilder: (context, item, index) =>
                  SizedBox(height: 40, child: Text(item)),
            ),
          ),
        ),
      );

      // Scroll past the prefetch threshold.
      await tester.drag(
        find.byType(OptimizedListView<String>),
        const Offset(
          0,
          -1400,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        reported,
        isA<StateError>(),
        reason: 'the parent must be told the prefetch failed',
      );
      expect(find.textContaining('PREFETCH BOOM'), findsOneWidget);
      expect(find.text(en.retry), findsOneWidget);
    });

    testWidgets('a failed load-more shows the error inline, and retrying '
        'clears it', (tester) async {
      var attempts = 0;

      await tester.pumpWidget(
        _wrap(
          OptimizedListView<String>(
            items: const ['Item 0', 'Item 1'],
            hasMore: true,
            enablePrefetch: false,
            onLoadMore: () async {
              attempts++;
              if (attempts == 1) {
                throw StateError('PREFETCH BOOM');
              }
              return (<String>[], false);
            },
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      // The trailing affordance is the load-more button until it fails.
      expect(find.text(en.loadMore), findsOneWidget);
      await tester.tap(find.text(en.loadMore));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.textContaining('PREFETCH BOOM'), findsOneWidget);
      expect(find.text(en.loadMore), findsNothing);

      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.textContaining('PREFETCH BOOM'), findsNothing);
    });
  });
}
