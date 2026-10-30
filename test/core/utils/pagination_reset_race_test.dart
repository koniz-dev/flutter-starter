// A page requested before reset() - page 2 of the old query - used to land
// after it: its items were appended to the new list, it advanced the page,
// and it cleared isLoading while the new query's load was still running.

import 'dart:async';

import 'package:flutter_starter/core/utils/pagination_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Completer<(List<String>, bool)>> pending;
  late String query;
  late PaginationHelper<String> helper;
  late Future<void> stale;

  setUp(() {
    pending = {};
    query = 'old';
    helper = PaginationHelper<String>(
      loadPage: (page) {
        final key = '$query:$page';
        final completer = pending[key] = Completer<(List<String>, bool)>();
        return completer.future;
      },
    );
  });

  /// Loads page 1 of "old", then starts page 2 and leaves it in [stale].
  Future<void> startStalePage() async {
    final first = helper.loadNextPage();
    pending['old:1']!.complete((['old:a1'], true));
    await first;
    stale = helper.loadNextPage();
  }

  test('a stale page landing after the new one changes nothing', () async {
    await startStalePage();
    query = 'new';
    helper.reset();
    final fresh = helper.loadNextPage();
    pending['new:1']!.complete((['new:b1'], true));
    await fresh;

    pending['old:2']!.complete((['old:a2'], true));
    await stale;

    expect(helper.state.items, ['new:b1']);
    expect(helper.state.currentPage, 2);
    expect(helper.state.isLoading, isFalse);
  });

  test(
    'a stale page landing while the new load runs leaves it loading',
    () async {
      await startStalePage();
      query = 'new';
      helper.reset();
      final fresh = helper.loadNextPage();

      pending['old:2']!.complete((['old:a2'], true));
      await stale;

      expect(helper.state.items, isEmpty);
      expect(helper.state.currentPage, 1);
      expect(helper.state.isLoading, isTrue, reason: 'the new load still runs');

      pending['new:1']!.complete((['new:b1'], true));
      await fresh;
      expect(helper.state.items, ['new:b1']);
    },
  );

  test('a stale failure after reset sets no error', () async {
    await startStalePage();
    helper.reset();

    pending['old:2']!.completeError(StateError('old query failed'));
    await stale;

    expect(helper.state.error, isNull);
    expect(helper.state.items, isEmpty);
  });
}
