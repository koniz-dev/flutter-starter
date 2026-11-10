// Blueprint: lib/core/security/session_manager.dart (add this file yourself)
import 'dart:async';

/// Manages user session timeout and activity tracking
class SessionManager {
  SessionManager({
    required this.tokenStore,
    required this.authRepository,
  });

  final ITokenStore tokenStore;
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
    try {
      if (await tokenStore.getAccessToken() == null) return;
    } on Object {
      // An unreadable credential must not skip the logout attempt.
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
abstract class ITokenStore { Future<String?> getAccessToken(); }
abstract class AuthRepository { Future<void> logout(); }
class Store implements ITokenStore {
  Store(this.value);
  final Object? value;
  @override Future<String?> getAccessToken() async {
    if (value != null && value is! String) throw value!;
    return value as String?;
  }
}
class Repository implements AuthRepository {
  int calls = 0;
  @override Future<void> logout() async { calls++; }
}
Future<void> main() async {
  for (final value in [null, 'bearer', Exception('read failed'), StateError('read failed')]) {
    final repository = Repository();
    final manager = SessionManager(tokenStore: Store(value), authRepository: repository);
    await manager._handleSessionTimeout();
    final expected = value == null ? 0 : 1;
    if (repository.calls != expected) throw StateError('Unexpected logout calls');
    print('read=$value logoutCalls=${repository.calls} expected=$expected PASS');
  }
}
