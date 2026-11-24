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

  /// Handle user activity (call from user interactions)
  void onUserActivity() {
    resetSessionTimer();
  }

  /// Call when the app returns to the foreground.
  ///
  /// A suspended app runs no timers, so the session may have expired in the
  /// background. Sign out first if it did, then start a fresh timer.
  Future<void> onResume() async {
    final lastActivity = _lastActivity;
    if (lastActivity != null &&
        DateTime.now().difference(lastActivity) >= sessionTimeout) {
      // Cleared first, so a second resume during sign-out does not repeat it.
      _sessionTimer?.cancel();
      _lastActivity = null;
      await _handleSessionTimeout();
    }
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
  print('resume handler calls: onResume');
  print('before resume: timeUntilTimeout=${manager.getTimeUntilTimeout()}');
  manager.onResume();
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('after resume: signOuts=$signOuts');
  manager.dispose();
}

