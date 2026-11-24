import 'dart:io' show sleep;
// Blueprint: lib/core/security/session_manager.dart (add this file yourself)
import 'dart:async';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';

/// Manages user session timeout and activity tracking
class SessionManager {
  SessionManager({
    required this.tokenStore,
    required this.signOut,
  });

  final ITokenStore tokenStore;
  final Future<void> Function() signOut;

  Timer? _sessionTimer;
  static const Duration sessionTimeout = Duration(milliseconds: 300);
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
    try {
      if (await tokenStore.getAccessToken() == null) return;
    } on Object {
      // An unreadable credential must not skip the logout attempt.
    }
    await signOut();
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

class _Tokens implements ITokenStore {
  String? token = 'access';
  @override
  Future<String?> getAccessToken() async => token;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  final tokens = _Tokens();
  var signOuts = 0;
  final manager = SessionManager(
    tokenStore: tokens,
    signOut: () async {
      signOuts++;
      tokens.token = null;
    },
  )..initialize();
  sleep(const Duration(milliseconds: 600));
  print('resume handler calls: onUserActivity');
  print('before resume: timeUntilTimeout=${manager.getTimeUntilTimeout()}');
  manager.onUserActivity();
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('after resume: signOuts=$signOuts');
  manager.dispose();
}

