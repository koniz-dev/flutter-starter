// A call in flight across reset() finished afterwards and wrote its result
// back: LazyInitializer brought the pre-reset value back, and
// DeferredImportLoader marked itself loaded and dropped the next load's
// future. LazyLoader already ignored loads from before clearCache(); both
// now do the same for reset().

import 'dart:async';

import 'package:flutter_starter/core/utils/lazy_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LazyInitializer: a get in flight across reset does not return '
      'the old value to later callers', () async {
    final pending = <Completer<String>>[];
    final initializer = LazyInitializer<String>(
      initializer: () {
        final completer = Completer<String>();
        pending.add(completer);
        return completer.future;
      },
    );

    final first = initializer.get();
    await pumpEventQueue();
    initializer.reset();
    final second = initializer.get();
    await pumpEventQueue();

    pending[0].complete('old');
    expect(await first, 'old');
    final third = initializer.get();
    pending[1].complete('new');

    expect(await second, 'new');
    expect(await third, 'new');
    expect(await initializer.get(), 'new');
  });

  test('DeferredImportLoader: a load in flight across reset does not mark '
      'the next load done', () async {
    final pending = <Completer<void>>[];
    final loader = DeferredImportLoader(
      loadFunction: () {
        final completer = Completer<void>();
        pending.add(completer);
        return completer.future;
      },
    );

    final first = loader.load();
    await pumpEventQueue();
    loader.reset();
    final second = loader.load();
    await pumpEventQueue();

    pending[0].complete();
    await first;
    expect(
      loader.isLoaded,
      isFalse,
      reason: 'only the load started after the reset may finish it',
    );
    final third = loader.load();
    await pumpEventQueue();
    expect(pending, hasLength(2), reason: 'third joins the pending load');

    pending[1].complete();
    await Future.wait([second, third]);
    expect(loader.isLoaded, isTrue);
  });
}
