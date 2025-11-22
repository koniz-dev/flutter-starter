import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/pagination_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaginationConfig', () {
    test('should create with default values', () {
      const config = PaginationConfig();

      expect(config.pageSize, 20);
      expect(config.initialPage, 1);
      expect(config.enablePrefetch, isTrue);
      expect(config.prefetchThreshold, 0.8);
    });

    test('should create with custom values', () {
      const config = PaginationConfig(
        pageSize: 50,
        initialPage: 0,
        enablePrefetch: false,
        prefetchThreshold: 0.9,
      );

      expect(config.pageSize, 50);
      expect(config.initialPage, 0);
      expect(config.enablePrefetch, isFalse);
      expect(config.prefetchThreshold, 0.9);
    });
  });

  group('PaginationState', () {
    test('should create with required parameters', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        hasMore: true,
      );

      expect(state.items, [1, 2, 3]);
      expect(state.currentPage, 1);
      expect(state.hasMore, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should create with all parameters', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 2,
        hasMore: false,
        isLoading: true,
        error: 'Test error',
      );

      expect(state.items, [1, 2, 3]);
      expect(state.currentPage, 2);
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isTrue);
      expect(state.error, 'Test error');
    });

    test('should copy with updated values', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        hasMore: true,
      );

      final newState = state.copyWith(
        items: [1, 2, 3, 4],
        currentPage: 2,
        hasMore: false,
        isLoading: true,
        error: 'Error',
      );

      expect(newState.items, [1, 2, 3, 4]);
      expect(newState.currentPage, 2);
      expect(newState.hasMore, isFalse);
      expect(newState.isLoading, isTrue);
      expect(newState.error, 'Error');
    });

    test('should copy with partial updates', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        hasMore: true,
      );

      final newState = state.copyWith(isLoading: true);

      expect(newState.items, [1, 2, 3]);
      expect(newState.currentPage, 1);
      expect(newState.hasMore, isTrue);
      expect(newState.isLoading, isTrue);
    });

    test('should append page', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        hasMore: true,
      );

      final newState = state.appendPage([4, 5, 6], hasMore: false);

      expect(newState.items, [1, 2, 3, 4, 5, 6]);
      expect(newState.currentPage, 2);
      expect(newState.hasMore, isFalse);
    });

    test('should set loading', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        hasMore: true,
      );

      final newState = state.setLoading(loading: true);

      expect(newState.isLoading, isTrue);
      expect(newState.items, [1, 2, 3]);
    });

    test('should set error', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        hasMore: true,
      );

      final newState = state.setError('Test error');

      expect(newState.error, 'Test error');
      expect(newState.items, [1, 2, 3]);
    });

    test('should reset', () {
      final state = PaginationState<int>(
        items: [1, 2, 3],
        currentPage: 3,
        hasMore: false,
        isLoading: true,
        error: 'Error',
      );

      final newState = state.reset();

      expect(newState.items, isEmpty);
      expect(newState.currentPage, 1);
      expect(newState.hasMore, isTrue);
      expect(newState.isLoading, isFalse);
      expect(newState.error, isNull);
    });
  });

  group('PaginationHelper', () {
    test('should create with loadPage function', () {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], true),
      );

      expect(helper, isNotNull);
      expect(helper.state.items, isEmpty);
      expect(helper.state.currentPage, 1);
      expect(helper.state.hasMore, isTrue);
    });

    test('should create with custom config', () {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], true),
        config: const PaginationConfig(pageSize: 50),
      );

      expect(helper, isNotNull);
    });

    test('should load next page', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async {
          if (page == 1) {
            return ([1, 2, 3], true);
          }
          return ([4, 5, 6], false);
        },
      );

      await helper.loadNextPage();

      expect(helper.state.items, [1, 2, 3]);
      expect(helper.state.currentPage, 2);
      expect(helper.state.hasMore, isTrue);
      expect(helper.state.isLoading, isFalse);
    });

    test('should append items on load', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async {
          if (page == 1) {
            return ([1, 2, 3], true);
          }
          return ([4, 5, 6], false);
        },
      );

      await helper.loadNextPage();
      await helper.loadNextPage();

      expect(helper.state.items, [1, 2, 3, 4, 5, 6]);
      expect(helper.state.currentPage, 3);
      expect(helper.state.hasMore, isFalse);
    });

    test('should not load when already loading', () async {
      var loadCount = 0;
      final helper = PaginationHelper<int>(
        loadPage: (page) async {
          loadCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ([1, 2, 3], true);
        },
      );

      helper.loadNextPage();
      helper.loadNextPage();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(loadCount, 1);
    });

    test('should not load when no more items', () async {
      var loadCount = 0;
      final helper = PaginationHelper<int>(
        loadPage: (page) async {
          loadCount++;
          return ([1, 2, 3], false);
        },
      );

      await helper.loadNextPage();
      await helper.loadNextPage();

      expect(loadCount, 1);
    });

    test('should handle load errors', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async {
          throw Exception('Load error');
        },
      );

      await helper.loadNextPage();

      expect(helper.state.error, isNotNull);
      expect(helper.state.isLoading, isFalse);
    });

    test('should reset pagination', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], true),
      );

      await helper.loadNextPage();
      expect(helper.state.items, isNotEmpty);

      helper.reset();
      expect(helper.state.items, isEmpty);
      expect(helper.state.currentPage, 1);
      expect(helper.state.hasMore, isTrue);
    });

    test('should check if should prefetch', () {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], true),
        config: const PaginationConfig(
          prefetchThreshold: 0.8,
        ),
      );

      expect(helper.shouldPrefetch(0.9), isTrue);
      expect(helper.shouldPrefetch(0.7), isFalse);
    });

    test('should not prefetch when disabled', () {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], true),
        config: const PaginationConfig(enablePrefetch: false),
      );

      expect(helper.shouldPrefetch(0.9), isFalse);
    });

    test('should not prefetch when loading', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ([1, 2, 3], true);
        },
      );

      helper.loadNextPage();
      expect(helper.shouldPrefetch(0.9), isFalse);
    });

    test('should not prefetch when no more items', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], false),
      );

      await helper.loadNextPage();
      expect(helper.shouldPrefetch(0.9), isFalse);
    });

    test('should check if should load next page', () {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], true),
      );

      expect(helper.shouldLoadNextPage(1), isTrue);
      expect(helper.shouldLoadNextPage(0.9), isFalse);
    });

    test('should not load next page when loading', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ([1, 2, 3], true);
        },
      );

      helper.loadNextPage();
      expect(helper.shouldLoadNextPage(1), isFalse);
    });

    test('should not load next page when no more items', () async {
      final helper = PaginationHelper<int>(
        loadPage: (page) async => ([1, 2, 3], false),
      );

      await helper.loadNextPage();
      expect(helper.shouldLoadNextPage(1), isFalse);
    });
  });

  group('PaginationScrollExtension', () {
    testWidgets('should calculate scroll ratio', (tester) async {
      final controller = ScrollController();
      final listView = ListView(
        controller: controller,
        children: List.generate(20, (i) => SizedBox(height: 100, child: Text('Item $i'))),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: listView),
        ),
      );

      await tester.pump();

      // Wait for layout
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to middle using jumpTo (no animation)
      if (controller.hasClients) {
        controller.jumpTo(controller.position.maxScrollExtent * 0.5);
        await tester.pump();

        expect(controller.scrollRatio, greaterThan(0.4));
        expect(controller.scrollRatio, lessThan(0.6));
      }
    });

    testWidgets('should check if near end', (tester) async {
      final controller = ScrollController();
      final listView = ListView(
        controller: controller,
        children: List.generate(20, (i) => SizedBox(height: 100, child: Text('Item $i'))),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: listView),
        ),
      );

      await tester.pump();

      // Wait for layout
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll near end using jumpTo (no animation)
      if (controller.hasClients) {
        controller.jumpTo(controller.position.maxScrollExtent * 0.85);
        await tester.pump();

        expect(controller.isNearEnd, isTrue);
      }
    });

    testWidgets('should check if at end', (tester) async {
      final controller = ScrollController();
      final listView = ListView(
        controller: controller,
        children: List.generate(20, (i) => SizedBox(height: 100, child: Text('Item $i'))),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: listView),
        ),
      );

      await tester.pump();

      // Wait for layout
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to end using jumpTo (no animation)
      if (controller.hasClients) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();

        expect(controller.isAtEnd, isTrue);
      }
    });

    test('should return 0 for scroll ratio when no clients', () {
      final controller = ScrollController();
      expect(controller.scrollRatio, 0);
    });
  });
}

