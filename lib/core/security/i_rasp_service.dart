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

  // The values below each carry exactly one freeRASP detection, one to one,
  // so a listener can tell them apart (koniz-dev/flutter-starter#390). Several
  // are device-posture signals rather than attacks; see the RASP section of
  // docs/guides/security/implementation.md before turning any of them into a
  // forced logout.

  /// A known malicious or suspicious app is installed. Android only.
  malware,

  /// The device bootloader is unlocked or otherwise compromised. Android
  /// only.
  unlockedBootloader,

  /// An automation or UI-driving framework is controlling the app. Android
  /// only.
  automation,

  /// The app is running as more than one instance, e.g. cloned by a
  /// dual-app or parallel-space tool. Android only.
  multiInstance,

  /// The device clock has been manipulated.
  timeSpoofing,

  /// The device location has been manipulated. Android only.
  locationSpoofing,

  /// A screenshot was taken while the app was in the foreground.
  screenshot,

  /// Screen recording started while the app was in the foreground.
  screenRecording,

  /// The device has no passcode, PIN or biometric lock set.
  passcodeNotSet,

  /// Android developer options are enabled. Android only.
  developerMode,

  /// Android Debug Bridge (ADB) is enabled. Android only.
  adbEnabled,

  /// A system-wide VPN is active.
  systemVpn,

  /// The device is on a Wi-Fi network with no or weak security. Android
  /// only.
  unsecureWiFi,
}

/// Interface for Runtime Application Self-Protection (RASP)
abstract class IRaspService {
  /// Start monitoring for security threats
  Future<void> startProtection();

  /// Stream of threats detected. Can be used to log or force logout.
  Stream<SecurityThreat> get onThreatDetected;
}
