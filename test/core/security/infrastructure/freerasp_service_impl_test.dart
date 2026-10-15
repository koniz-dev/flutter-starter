// Drives FreeRaspServiceImpl against freerasp's real Dart API with its
// platform channels mocked, so a freerasp upgrade that changes how threats
// reach the listener fails here rather than only on a device
// (koniz-dev/flutter-starter#388).
//
// The target platform is overridden to iOS. The shipped placeholder signing
// hash fails freeRASP's Android config check, which runs in the
// `AndroidConfig` constructor on 6.12 and 8.x alike and only when the target
// platform is Android, so on Android startProtection() throws before the
// listener is attached. That is koniz-dev/flutter-starter#317, not what is
// under test here; the iOS placeholder passes freeRASP's iOS check.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';
import 'package:flutter_starter/core/security/infrastructure/freerasp_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('talsec.app/freerasp/methods');
  const events = EventChannel('talsec.app/freerasp/events');

  /// freeRASP's wire code for `Threat.debug` (`ThreatX.fromInt`).
  const debugThreatCode = 1268968002;

  test('a threat freeRASP reports reaches onThreatDetected', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final methodCalls = <String>[];
    MockStreamHandlerEventSink? threatSink;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(methods, (call) async {
            methodCalls.add(call.method);
            return null;
          })
          ..setMockStreamHandler(
            events,
            MockStreamHandler.inline(onListen: (_, sink) => threatSink = sink),
          );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(methods, null)
        ..setMockStreamHandler(events, null);
    });

    final service = FreeRaspServiceImpl();
    final threats = <SecurityThreat>[];
    final subscription = service.onThreatDetected.listen(threats.add);
    addTearDown(subscription.cancel);

    await service.startProtection();
    await pumpEventQueue();

    expect(methodCalls, contains('start'));
    expect(threatSink, isNotNull, reason: 'the listener subscribed');
    threatSink!.success(debugThreatCode);
    await pumpEventQueue();

    expect(threats, [SecurityThreat.debugger]);
  });
}
