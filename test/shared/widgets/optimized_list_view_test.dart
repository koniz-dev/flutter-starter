import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/widgets/optimized_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OptimizedListView', () {
    testWidgets('should display items', (tester) async {
      final items = ['Item 1', 'Item 2', 'Item 3'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: items,
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('should show empty state when items are empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const [],
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        ),
      );

      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('should show loading indicator when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const ['Item 1'],
              itemBuilder: (context, item, index) => Text(item),
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error message when error occurs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const ['Item 1'],
              itemBuilder: (context, item, index) => Text(item),
              error: 'Error loading items',
            ),
          ),
        ),
      );

      expect(find.text('Error loading items'), findsOneWidget);
    });

    testWidgets('should show retry button when error and onRetry provided', (
      tester,
    ) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const ['Item 1'],
              itemBuilder: (context, item, index) => Text(item),
              error: 'Error loading items',
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        ),
      );

      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      expect(retryCalled, isTrue);
    });

    testWidgets('should show load more button when hasMore is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const ['Item 1'],
              itemBuilder: (context, item, index) => Text(item),
              hasMore: true,
            ),
          ),
        ),
      );

      expect(find.text('Load More'), findsOneWidget);
    });

    testWidgets('should call onLoadMore when load more button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const ['Item 1'],
              itemBuilder: (context, item, index) => Text(item),
              hasMore: true,
              onLoadMore: () async {
                return (<String>['Item 2'], false);
              },
            ),
          ),
        ),
      );

      final loadMoreButton = find.text('Load More');
      expect(loadMoreButton, findsOneWidget);

      await tester.tap(loadMoreButton);
      await tester.pump();
    });

    testWidgets('should support custom padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const ['Item 1'],
              itemBuilder: (context, item, index) => Text(item),
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('should support itemExtent for better performance', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: const ['Item 1', 'Item 2'],
              itemBuilder: (context, item, index) => Text(item),
              itemExtent: 50,
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('should handle scroll to trigger prefetch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptimizedListView<String>(
              items: List.generate(20, (i) => 'Item $i'),
              itemBuilder: (context, item, index) => SizedBox(
                height: 100,
                child: Text(item),
              ),
              hasMore: true,
              onLoadMore: () async {
                return (<String>[], false);
              },
            ),
          ),
        ),
      );

      // Scroll to trigger prefetch
      await tester.drag(
        find.byType(OptimizedListView<String>),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Note: Actual prefetch behavior depends on scroll position
      // This test verifies the widget handles scrolling
      expect(find.byType(OptimizedListView<String>), findsOneWidget);
    });
  });
}
