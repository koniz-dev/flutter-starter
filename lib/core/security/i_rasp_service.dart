/// Represents potential security threats
enum SecurityThreat {
  /// Running on rooted or jailbroken device
  privilegedAccess,

  /// Running in an emulator or simulator
  emulator,

  /// App is being debugged
  debugger,

  /// App installer is not trusted (not from Play Store/App Store)
  unofficialStore,

  /// App signature doesn't match
  tampered,

  /// General/Unknown threat
  unknown,
}

/// Interface for Runtime Application Self-Protection (RASP)
abstract class IRaspService {
  /// Start monitoring for security threats
  Future<void> startProtection();

  /// Stream of threats detected. Can be used to log or force logout.
  Stream<SecurityThreat> get onThreatDetected;
}
