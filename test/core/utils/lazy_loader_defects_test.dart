// LazyLoader must not crash on a failed preload, nor resurrect a cleared
// cache.
//
// preload() fired `unawaited(load(key))`, so a loader failure became an
// uncaught zone error; and clearCache() during a load was undone when the load
// completed, because the completion wrote the cache regardless.

import 'dart:async';

import 'package:flutter_starter/core/utils/lazy_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('criterion 1: a failing preload records no uncaught error', () async {
    final uncaught = <Object>[];

    await runZonedGuarded(() async {
      final loader = LazyLoader<String, String>(
        loader: (_) async => throw StateError('offline'),
      )..preload('a');
      await pumpEventQueue();

      expect(loader.isCached('a'), isFalse);
      expect(loader.isLoading('a'), isFalse);
    }, (error, _) => uncaught.add(error));

    expect(uncaught, isEmpty);
  });

  test('a failed preload leaves the key to be retried by load', () async {
    var calls = 0;
    final loader = LazyLoader<String, String>(
      loader: (key) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return 'v-$key';
      },
    )..preload('a');
    await pumpEventQueue();

    expect(await loader.load('a'), 'v-a');
    expect(calls, 2);
  });

  test('criterion 2: clearCache() during a load is not undone when it '
      'completes', () async {
    final gate = Completer<String>();
    final loader = LazyLoader<String, String>(loader: (_) => gate.future);

    final pending = loader.load('a');
    loader.clearCache();
    gate.complete('v');

    expect(await pending, 'v', reason: 'the caller still gets its value');
    expect(loader.isCached('a'), isFalse);
  });

  test('evict() during a load is not undone either', () async {
    final gate = Completer<String>();
    final loader = LazyLoader<String, String>(loader: (_) => gate.future);

    final pending = loader.load('a');
    loader.evict('a');
    gate.complete('v');
    await pending;

    expect(loader.isCached('a'), isFalse);
  });

  test('a load that starts after clearCache() caches as normal', () async {
    final loader = LazyLoader<String, String>(loader: (k) async => 'v-$k')
      ..clearCache();

    await loader.load('a');

    expect(loader.isCached('a'), isTrue);
  });
}
