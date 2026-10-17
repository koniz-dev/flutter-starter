import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';
import 'package:freerasp/freerasp.dart';

/// Concrete implementation of [IRaspService] using the freerasp package
///
/// Every detection freeRASP reports is forwarded to [onThreatDetected]: each
/// [Threat] through [securityThreatFor], and malware, which freeRASP delivers
/// on its own callback rather than as a [Threat], as
/// [SecurityThreat.malware]. Nothing is dropped. Until
/// koniz-dev/flutter-starter#390 the callback set only 10 of freeRASP's 23
/// callbacks, so malware, an unlocked bootloader and automation, among
/// others, never reached a listener.
class FreeRaspServiceImpl implements IRaspService {
  final _threatController = StreamController<SecurityThreat>.broadcast();

  /// Set only once a start has *succeeded*. It used to be set before the
  /// start was even attempted, so a start that threw - as the shipped
  /// placeholder config does on Android - turned every later call into a
  /// silent no-op that protected nothing (koniz-dev/flutter-starter#317).
  bool _started = false;

  /// The start in flight, shared by concurrent callers so protection is
  /// started once; cleared when it settles, so a failed start can be retried.
  Future<void>? _starting;

  @override
  Stream<SecurityThreat> get onThreatDetected => _threatController.stream;

  /// The [SecurityThreat] a freeRASP [threat] is reported as.
  ///
  /// The switch is exhaustive on purpose: a freerasp upgrade that adds a
  /// [Threat] stops compiling here until someone decides what it maps to.
  /// The callback wiring in [startProtection] is checked separately, by
  /// test/core/security/infrastructure/freerasp_service_impl_test.dart.
  @visibleForTesting
  static SecurityThreat securityThreatFor(Threat threat) => switch (threat) {
    Threat.appIntegrity => SecurityThreat.tampered,
    Threat.obfuscationIssues => SecurityThreat.tampered,
    Threat.debug => SecurityThreat.debugger,
    Threat.deviceBinding => SecurityThreat.unknown,
    Threat.deviceId => SecurityThreat.unknown,
    Threat.hooks => SecurityThreat.privilegedAccess,
    Threat.privilegedAccess => SecurityThreat.privilegedAccess,
    Threat.secureHardwareNotAvailable => SecurityThreat.unknown,
    Threat.simulator => SecurityThreat.emulator,
    Threat.unofficialStore => SecurityThreat.unofficialStore,
    Threat.bootloader => SecurityThreat.unlockedBootloader,
    Threat.automation => SecurityThreat.automation,
    Threat.multiInstance => SecurityThreat.multiInstance,
    Threat.timeSpoofing => SecurityThreat.timeSpoofing,
    Threat.locationSpoofing => SecurityThreat.locationSpoofing,
    Threat.screenshot => SecurityThreat.screenshot,
    Threat.screenRecording => SecurityThreat.screenRecording,
    Threat.passcode => SecurityThreat.passcodeNotSet,
    Threat.devMode => SecurityThreat.developerMode,
    Threat.adbEnabled => SecurityThreat.adbEnabled,
    Threat.systemVPN => SecurityThreat.systemVpn,
    Threat.unsecureWiFi => SecurityThreat.unsecureWiFi,
  };

  void _report(Threat threat) =>
      _threatController.add(securityThreatFor(threat));

  @override
  Future<void> startProtection() {
    if (_started) return Future<void>.value();
    return _starting ??= _start()
        .then((_) => _started = true)
        .whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    // PLACEHOLDER - REPLACE BEFORE ENABLING RASP. None of these values
    // identify a real app: freeRASP rejects the Android signing hash below,
    // so startProtection() throws on Android until it is replaced. See
    // docs/guides/security/implementation.md ("Edit the placeholder
    // TalsecConfig").
    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: 'com.example.flutter_starter',
        signingCertHashes: ['AKa...'], // Replace with actual hashes
        supportedStores: ['com.sec.android.app.samsungapps'],
      ),
      iosConfig: IOSConfig(
        bundleIds: ['com.example.flutterStarter'],
        teamId: 'YOUR_TEAM_ID',
      ),
      watcherMail: 'your_email@example.com',
      isProd: kReleaseMode,
    );

    // One argument per ThreatCallback parameter. freeRASP drops a detection
    // whose callback is null, without logging it.
    final callback = ThreatCallback(
      onAppIntegrity: () => _report(Threat.appIntegrity),
      onObfuscationIssues: () => _report(Threat.obfuscationIssues),
      onDebug: () => _report(Threat.debug),
      onDeviceBinding: () => _report(Threat.deviceBinding),
      onDeviceID: () => _report(Threat.deviceId),
      onHooks: () => _report(Threat.hooks),
      onPrivilegedAccess: () => _report(Threat.privilegedAccess),
      onSecureHardwareNotAvailable: () =>
          _report(Threat.secureHardwareNotAvailable),
      onSimulator: () => _report(Threat.simulator),
      onUnofficialStore: () => _report(Threat.unofficialStore),
      onBootloader: () => _report(Threat.bootloader),
      onAutomation: () => _report(Threat.automation),
      onMultiInstance: () => _report(Threat.multiInstance),
      onTimeSpoofing: () => _report(Threat.timeSpoofing),
      onLocationSpoofing: () => _report(Threat.locationSpoofing),
      onScreenshot: () => _report(Threat.screenshot),
      onScreenRecording: () => _report(Threat.screenRecording),
      onPasscode: () => _report(Threat.passcode),
      onDevMode: () => _report(Threat.devMode),
      onADBEnabled: () => _report(Threat.adbEnabled),
      onSystemVPN: () => _report(Threat.systemVPN),
      onUnsecureWiFi: () => _report(Threat.unsecureWiFi),
      onMalware: (_) => _threatController.add(SecurityThreat.malware),
    );

    await Talsec.instance.attachListener(callback);
    await Talsec.instance.start(config);
  }
}
