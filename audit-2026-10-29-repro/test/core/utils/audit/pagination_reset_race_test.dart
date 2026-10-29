import 'dart:async';

import 'package:flutter_starter/core/utils/pagination_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a page requested before reset() does not land after it', () async {
    final pending = <int, Completer<(List<String>, bool)>>{};
    var query = 'old';
    final helper = PaginationHelper<String>(
      loadPage: (page) {
        final c = Completer<(List<String>, bool)>();
        pending[page] = c;
        final q = query;
        return c.future.then((r) => (r.$1.map((i) => '$q:$i').toList(), r.$2));
      },
    );

    final first = helper.loadNextPage();
    pending[1]!.complete((['a1'], true));
    await first;
    final stale = helper.loadNextPage(); // page 2 of "old", in flight

    // The user changes the search: reset and load page 1 of "new".
    query = 'new';
    helper.reset();
    final fresh = helper.loadNextPage();
    pending[1]!.complete((['b1'], true)); // overwritten entry is page 1 "new"
    await fresh;
    pendingCompleteOld(pending);
    await stale;

    print('items=${helper.state.items} currentPage=${helper.state.currentPage}');
    expect(helper.state.items, ['new:b1']);
    expect(helper.state.currentPage, 2);
  });
}

void pendingCompleteOld(Map<int, Completer<(List<String>, bool)>> p) =>
    p[2]!.complete((['a2'], true));
