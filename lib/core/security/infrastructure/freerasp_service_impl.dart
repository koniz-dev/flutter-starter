import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';
import 'package:freerasp/freerasp.dart';

/// Concrete implementation of [IRaspService] using the freerasp package
class FreeRaspServiceImpl implements IRaspService {
  final _threatController = StreamController<SecurityThreat>.broadcast();
  bool _initialized = false;

  @override
  Stream<SecurityThreat> get onThreatDetected => _threatController.stream;

  @override
  Future<void> startProtection() async {
    if (_initialized) return;
    _initialized = true;

    // Use a placeholder config.
    // Developers should replace these with their actual production hashes.
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

    final callback = ThreatCallback(
      onAppIntegrity: () => _threatController.add(SecurityThreat.tampered),
      onObfuscationIssues: () => _threatController.add(SecurityThreat.tampered),
      onDebug: () => _threatController.add(SecurityThreat.debugger),
      onDeviceBinding: () => _threatController.add(SecurityThreat.unknown),
      onDeviceID: () => _threatController.add(SecurityThreat.unknown),
      onHooks: () => _threatController.add(SecurityThreat.privilegedAccess),
      onPrivilegedAccess: () =>
          _threatController.add(SecurityThreat.privilegedAccess),
      onSecureHardwareNotAvailable: () =>
          _threatController.add(SecurityThreat.unknown),
      onSimulator: () => _threatController.add(SecurityThreat.emulator),
      onUnofficialStore: () =>
          _threatController.add(SecurityThreat.unofficialStore),
    );

    Talsec.instance.attachListener(callback);
    await Talsec.instance.start(config);
  }
}
