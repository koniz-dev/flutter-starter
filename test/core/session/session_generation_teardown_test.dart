// SessionGeneration records the teardowns that follow an invalidate, so a
// sign-in can wait for them before it stores credentials they would delete.

import 'dart:async';

import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_test/flutter_test.dart';

const _limit = Duration(seconds: 5);

void main() {
  late SessionGeneration generation;

  setUp(() => generation = SessionGeneration());

  test('nothing tracked: settled at once', () async {
    expect(await generation.teardownsSettled(_limit), isTrue);
  });

  test('waits for a tracked teardown', () async {
    final teardown = Completer<void>();
    generation.trackTeardown(teardown.future);
    var settled = false;
    final wait = generation.teardownsSettled(_limit).then((ok) {
      settled = ok;
    });
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);

    teardown.complete();
    await wait;
    expect(settled, isTrue);
  });

  test('also waits for one tracked while it was waiting', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    generation.trackTeardown(first.future);
    var settled = false;
    final wait = generation.teardownsSettled(_limit).then((ok) {
      settled = ok;
    });
    generation.trackTeardown(second.future);
    first.complete();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(settled, isFalse, reason: 'the second is still running');

    second.complete();
    await wait;
    expect(settled, isTrue);
  });

  test('a teardown that fails still settles, and nothing escapes', () async {
    final teardown = Completer<void>();
    generation.trackTeardown(teardown.future);
    teardown.completeError(StateError('clear failed'));
    // The caller that owns the teardown sees the error itself.
    await expectLater(teardown.future, throwsStateError);

    expect(await generation.teardownsSettled(_limit), isTrue);
  });

  test('false once the limit passes', () async {
    generation.trackTeardown(Completer<void>().future); // never settles

    expect(
      await generation.teardownsSettled(const Duration(milliseconds: 20)),
      isFalse,
    );
  });
}
