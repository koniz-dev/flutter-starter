# Security blueprints (optional modules)

Code in this file is **not** checked into the starter. Use it as a copy-paste starting point after you read the [Implementation guide](./implementation.md) and [Audit](./audit.md).

---

## Session management

### Step 1: Session manager

```dart
// Blueprint: lib/core/security/session_manager.dart (add this file yourself)
import 'dart:async';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Manages user session timeout and activity tracking
class SessionManager {
  SessionManager({
    required this.secureStorageService,
    required this.authRepository,
  });

  final SecureStorageService secureStorageService;
  final AuthRepository authRepository;

  Timer? _sessionTimer;
  static const Duration sessionTimeout = Duration(hours: 24);
  DateTime? _lastActivity;

  /// Initialize session manager
  void initialize() {
    resetSessionTimer();
    _lastActivity = DateTime.now();
  }

  /// Reset session timer (call on user activity)
  void resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(
      sessionTimeout,
      () => unawaited(_handleSessionTimeout()),
    );
    _lastActivity = DateTime.now();
  }

  /// Handle user activity (call from app lifecycle or user interactions)
  void onUserActivity() {
    resetSessionTimer();
  }

  Future<void> _handleSessionTimeout() async {
    final token = await secureStorageService.getString(AppConstants.tokenKey);
    if (token == null) {
      return;
    }
    await authRepository.logout();
  }

  Duration? getTimeUntilTimeout() {
    if (_lastActivity == null) return null;
    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = sessionTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void dispose() {
    _sessionTimer?.cancel();
  }
}
```

### Step 2: App lifecycle (illustrative)

```dart
// Illustrative only — this starter uses ConsumerWidget + go_router; adapt DI.
import 'package:flutter/material.dart';
import 'package:flutter_starter/core/security/session_manager.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  SessionManager? _sessionManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire your own ProviderContainer / ref to build SessionManager
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionManager?.onUserActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(/* … */);
  }
}
```

---

## GDPR and consent UI

### Step 1: Consent manager

```dart
// Blueprint: lib/core/privacy/consent_manager.dart
import 'package:flutter_starter/core/storage/secure_storage_service.dart';

/// Manages user consent for GDPR-style workflows
class ConsentManager {
  ConsentManager(this.secureStorageService);

  final SecureStorageService secureStorageService;

  static const String consentKey = 'user_consent_given';
  static const String consentVersionKey = 'consent_version';
  static const String consentTimestampKey = 'consent_timestamp';
  static const int currentConsentVersion = 1;

  Future<bool> hasUserConsented() async {
    final consented = await secureStorageService.getBool(consentKey);
    final version = await secureStorageService.getInt(consentVersionKey);
    return consented == true && version == currentConsentVersion;
  }

  Future<void> recordConsent({
    required bool accepted,
    required Map<String, bool> consentDetails,
  }) async {
    await secureStorageService.setBool(consentKey, value: accepted);
    await secureStorageService.setInt(consentVersionKey, currentConsentVersion);
    await secureStorageService.setInt(
      consentTimestampKey,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    for (final entry in consentDetails.entries) {
      await secureStorageService.setBool(
        'consent_${entry.key}',
        value: entry.value,
      );
    }
    if (accepted) {
      await _applyConsentPreferences(consentDetails);
    } else {
      await _revokeConsent();
    }
  }

  Future<void> _applyConsentPreferences(Map<String, bool> preferences) async {
    // Wire analytics / crash / marketing from preferences
  }

  Future<void> _revokeConsent() async {
    // Disable vendors, delete IDs where required
  }

  Future<DateTime?> getConsentTimestamp() async {
    final timestamp = await secureStorageService.getInt(consentTimestampKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  Future<bool> needsConsentRenewal() async {
    final timestamp = await getConsentTimestamp();
    if (timestamp == null) return true;
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    return timestamp.isBefore(oneYearAgo);
  }
}
```

### Step 2: Consent screen

```dart
// Blueprint: lib/features/privacy/presentation/screens/consent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/privacy/consent_manager.dart';

// Add consentManagerProvider in your DI layer.

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _analyticsConsent = false;
  bool _crashReportingConsent = false;
  bool _marketingConsent = false;

  Future<void> _handleConsent(bool accepted) async {
    final consentManager = ref.read(consentManagerProvider);
    await consentManager.recordConsent(
      accepted: accepted,
      consentDetails: {
        'analytics': _analyticsConsent,
        'crash_reporting': _crashReportingConsent,
        'marketing': _marketingConsent,
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Consent')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('We value your privacy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Analytics'),
              value: _analyticsConsent,
              onChanged: (v) => setState(() => _analyticsConsent = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Crash Reporting'),
              value: _crashReportingConsent,
              onChanged: (v) =>
                  setState(() => _crashReportingConsent = v ?? false),
            ),
            CheckboxListTile(
              title: const Text('Marketing'),
              value: _marketingConsent,
              onChanged: (v) =>
                  setState(() => _marketingConsent = v ?? false),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _handleConsent(true),
              child: const Text('Accept All'),
            ),
            OutlinedButton(
              onPressed: () => _handleConsent(false),
              child: const Text('Reject All'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

[← Back to implementation guide](./implementation.md)
