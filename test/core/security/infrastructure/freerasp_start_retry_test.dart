// A failed startProtection() must stay retryable, and concurrent calls must
// start protection once (koniz-dev/flutter-starter#317).
//
// The service marked itself initialized before the start was attempted, so a
// start that threw - which the shipped placeholder config does on Android -
// made every later call return normally and protect nothing. These tests use
// freerasp's real Dart API over mocked platform channels, as
// freerasp_service_impl_test.dart does.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/security/infrastructure/freerasp_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('talsec.app/freerasp/methods');
  const events = EventChannel('talsec.app/freerasp/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> methodCalls;
  Completer<void>? holdStart;

  void mockChannels(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    methodCalls = <String>[];
    messenger
      ..setMockMethodCallHandler(methods, (call) async {
        methodCalls.add(call.method);
        if (call.method == 'start') await holdStart?.future;
        return null;
      })
      ..setMockStreamHandler(
        events,
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    addTearDown(() {
      holdStart = null;
      messenger
        ..setMockMethodCallHandler(methods, null)
        ..setMockStreamHandler(events, null);
    });
  }

  test('criterion 1: after a failed start, a second call attempts the start '
      'again and fails again instead of returning normally', () async {
    // On Android the placeholder signing hash fails freeRASP's own config
    // validation, so every attempt throws.
    mockChannels(TargetPlatform.android);
    final service = FreeRaspServiceImpl();

    final first = await _thrownBy(service.startProtection());
    final second = await _thrownBy(service.startProtection());

    expect(first, isNotNull, reason: 'the placeholder config must be rejected');
    expect(
      second,
      isNotNull,
      reason: 'a failed start must not leave the service marked started',
    );
    expect(second.runtimeType, first.runtimeType);
  });

  test('criterion 2: concurrent calls start protection once', () async {
    // iOS: the placeholder passes freeRASP's iOS check, so the start reaches
    // the (mocked) native side, where it is held open.
    mockChannels(TargetPlatform.iOS);
    holdStart = Completer<void>();
    final service = FreeRaspServiceImpl();

    final calls = [
      service.startProtection(),
      service.startProtection(),
      service.startProtection(),
    ];
    await pumpEventQueue();
    holdStart!.complete();
    await Future.wait(calls);

    expect(methodCalls.where((m) => m == 'start'), hasLength(1));

    // Once started, a later call is a no-op.
    await service.startProtection();
    expect(methodCalls.where((m) => m == 'start'), hasLength(1));
  });
}

Future<Object?> _thrownBy(Future<void> future) async {
  try {
    await future;
    return null;
  } on Object catch (e) {
    return e;
  }
}
