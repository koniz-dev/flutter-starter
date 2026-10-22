// Drives FreeRaspServiceImpl against freerasp's real Dart API with its
// platform channels mocked, so a freerasp upgrade that changes how threats
// reach the listener fails here rather than only on a device.
//
// The target platform is overridden to iOS. The shipped placeholder signing
// hash fails freeRASP's Android config check, which runs in the
// `AndroidConfig` constructor on 6.12 and 8.x alike and only when the target
// platform is Android, so on Android startProtection() throws before the
// listener is attached. That is a separate limitation, not what is under
// test here; the iOS placeholder passes freeRASP's iOS check. The
// Dart-side wiring under test does not depend on the platform.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';
import 'package:flutter_starter/core/security/infrastructure/freerasp_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freerasp/freerasp.dart';

/// freeRASP's wire code for every [Threat], copied from `ThreatX.fromInt` in
/// the pinned freerasp. The test below checks each one round-trips, and that
/// this table covers every [Threat] value.
const _wireCodes = <Threat, int>{
  Threat.debug: 1268968002,
  Threat.hooks: 209533833,
  Threat.passcode: 1293399086,
  Threat.deviceId: 1514211414,
  Threat.simulator: 477190884,
  Threat.appIntegrity: 1115787534,
  Threat.obfuscationIssues: 1001443554,
  Threat.deviceBinding: 1806586319,
  Threat.unofficialStore: 629780916,
  Threat.privilegedAccess: 44506749,
  Threat.secureHardwareNotAvailable: 1564314755,
  Threat.systemVPN: 659382561,
  Threat.devMode: 45291047,
  Threat.adbEnabled: 379769839,
  Threat.screenshot: 705651459,
  Threat.screenRecording: 64690214,
  Threat.multiInstance: 859307284,
  Threat.unsecureWiFi: 363588890,
  Threat.timeSpoofing: 189105221,
  Threat.locationSpoofing: 653273273,
  Threat.automation: 298453120,
  Threat.bootloader: 1651076936,
};

/// What each detection must reach a listener as. This is the documented
/// mapping in docs/guides/security/implementation.md ("What the adapter
/// forwards").
const _expected = <Threat, SecurityThreat>{
  Threat.appIntegrity: SecurityThreat.tampered,
  Threat.obfuscationIssues: SecurityThreat.tampered,
  Threat.debug: SecurityThreat.debugger,
  Threat.deviceBinding: SecurityThreat.unknown,
  Threat.deviceId: SecurityThreat.unknown,
  Threat.hooks: SecurityThreat.privilegedAccess,
  Threat.privilegedAccess: SecurityThreat.privilegedAccess,
  Threat.secureHardwareNotAvailable: SecurityThreat.unknown,
  Threat.simulator: SecurityThreat.emulator,
  Threat.unofficialStore: SecurityThreat.unofficialStore,
  Threat.bootloader: SecurityThreat.unlockedBootloader,
  Threat.automation: SecurityThreat.automation,
  Threat.multiInstance: SecurityThreat.multiInstance,
  Threat.timeSpoofing: SecurityThreat.timeSpoofing,
  Threat.locationSpoofing: SecurityThreat.locationSpoofing,
  Threat.screenshot: SecurityThreat.screenshot,
  Threat.screenRecording: SecurityThreat.screenRecording,
  Threat.passcode: SecurityThreat.passcodeNotSet,
  Threat.devMode: SecurityThreat.developerMode,
  Threat.adbEnabled: SecurityThreat.adbEnabled,
  Threat.systemVPN: SecurityThreat.systemVpn,
  Threat.unsecureWiFi: SecurityThreat.unsecureWiFi,
};

/// Detections the adapter deliberately does not forward, each with a reason.
/// Empty: every detection of the pinned freerasp is forwarded. A future entry
/// must say why, and docs/guides/security/implementation.md must list it.
const _deliberatelyIgnored = <Threat, String>{};

/// The pigeon channel freeRASP 8.x delivers malware on, outside the [Threat]
/// stream.
const _malwareChannel =
    'dev.flutter.pigeon.freerasp.TalsecPigeonApi.onMalwareDetected';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('talsec.app/freerasp/methods');
  const events = EventChannel('talsec.app/freerasp/events');

  late List<String> methodCalls;
  late List<SecurityThreat> threats;
  MockStreamHandlerEventSink? threatSink;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Starts a fresh service on mocked channels; [threats] collects what it
  /// reports and [threatSink] plays freeRASP's native side.
  Future<void> startService() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    methodCalls = <String>[];
    threats = <SecurityThreat>[];
    threatSink = null;
    messenger
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
    final subscription = service.onThreatDetected.listen(threats.add);
    addTearDown(subscription.cancel);

    await service.startProtection();
    await pumpEventQueue();
    expect(methodCalls, contains('start'));
    expect(threatSink, isNotNull, reason: 'the listener subscribed');
  }

  test('a threat freeRASP reports reaches onThreatDetected', () async {
    await startService();

    threatSink!.success(_wireCodes[Threat.debug]);
    await pumpEventQueue();

    expect(threats, [SecurityThreat.debugger]);
  });

  group('every freeRASP detection is forwarded or deliberately ignored', () {
    test('the wire-code table covers every Threat of the pinned freerasp', () {
      // A freerasp upgrade that adds a Threat fails here first: add its code
      // from ThreatX.fromInt, then map it or list it as ignored.
      expect(
        Threat.values.toSet().difference(_wireCodes.keys.toSet()),
        isEmpty,
        reason: 'copy the new code from ThreatX.fromInt in freerasp',
      );
      for (final MapEntry(key: threat, value: code) in _wireCodes.entries) {
        expect(ThreatX.fromInt(code), threat, reason: 'code $code');
      }
    });

    test('every Threat is either mapped or in the ignored set', () {
      final unaccounted = Threat.values
          .where(
            (t) =>
                !_expected.containsKey(t) &&
                !_deliberatelyIgnored.containsKey(t),
          )
          .toList();

      expect(unaccounted, isEmpty);
      expect(
        _expected.keys.toSet().intersection(_deliberatelyIgnored.keys.toSet()),
        isEmpty,
        reason: 'a Threat cannot be both forwarded and ignored',
      );
    });

    test('securityThreatFor maps every Threat as documented', () {
      for (final MapEntry(key: threat, value: expected) in _expected.entries) {
        expect(
          FreeRaspServiceImpl.securityThreatFor(threat),
          expected,
          reason: '$threat',
        );
      }
    });

    for (final threat in Threat.values) {
      test('$threat sent by freeRASP reaches a listener', () async {
        await startService();

        threatSink!.success(_wireCodes[threat]);
        await pumpEventQueue();

        if (_deliberatelyIgnored.containsKey(threat)) {
          expect(threats, isEmpty, reason: _deliberatelyIgnored[threat]);
        } else {
          // A null ThreatCallback parameter is exactly how 13 detections were
          // dropped without a trace before: nothing arrives at all.
          expect(threats, [_expected[threat]]);
        }
      });
    }

    test(
      'malware, delivered outside the Threat stream, is forwarded',
      () async {
        await startService();

        // freeRASP 8.x reports malware over a pigeon channel with the list of
        // suspicious apps; an empty list is enough to fire the callback.
        final reply = await messenger.handlePlatformMessage(
          _malwareChannel,
          const StandardMessageCodec().encodeMessage(<Object?>[<Object?>[]]),
          (_) {},
        );
        await pumpEventQueue();

        // Pigeon answers a handled call with an empty list; an error would be
        // [code, message, details].
        expect(
          const StandardMessageCodec().decodeMessage(reply),
          isEmpty,
          reason: 'freeRASP handled the call without an error',
        );
        expect(threats, [SecurityThreat.malware]);
      },
    );
  });
}
