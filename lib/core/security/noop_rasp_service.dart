import 'package:flutter_starter/core/security/i_rasp_service.dart';

/// Default no-op implementation for [IRaspService].
///
/// This allows the app to run without any RASP vendor integration.
class NoOpRaspService implements IRaspService {
  @override
  Stream<SecurityThreat> get onThreatDetected =>
      const Stream<SecurityThreat>.empty();

  @override
  Future<void> startProtection() async {}
}
