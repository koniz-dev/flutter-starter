// A loader that throws before returning a future (input validation, say)
// reached the catch at once, which cleared the in-flight entry before the
// caller stored it. The stored failed future was then returned on every later
// call, and the loader never ran again.

import 'package:flutter_starter/core/utils/lazy_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LazyLoader calls the loader again after it threw synchronously',
    () async {
      var calls = 0;
      final loader = LazyLoader<String, int>(
        loader: (key) {
          calls++;
          if (calls == 1) throw StateError('sync');
          return Future.value(42);
        },
      );

      await expectLater(loader.load('a'), throwsStateError);
      expect(loader.isLoading('a'), isFalse);
      expect(await loader.load('a'), 42);
      expect(calls, 2);
    },
  );

  test('LazyInitializer calls the initializer again after it threw '
      'synchronously', () async {
    var calls = 0;
    final initializer = LazyInitializer<int>(
      initializer: () {
        calls++;
        if (calls == 1) throw StateError('sync');
        return Future.value(7);
      },
    );

    await expectLater(initializer.get(), throwsStateError);
    expect(await initializer.get(), 7);
    expect(calls, 2);
  });

  test('DeferredImportLoader calls the load function again after it threw '
      'synchronously', () async {
    var calls = 0;
    final deferred = DeferredImportLoader(
      loadFunction: () {
        calls++;
        if (calls == 1) throw StateError('sync');
        return Future<void>.value();
      },
    );

    await expectLater(deferred.load(), throwsStateError);
    await deferred.load();
    expect(calls, 2);
  });
}
