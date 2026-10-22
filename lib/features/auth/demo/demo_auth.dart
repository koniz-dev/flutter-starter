import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';

/// Offline demo sign-in, so a fresh copy of the app runs end to end before it
/// has a backend.
///
/// It is on only in a debug build with no backend - [AppConfig.hasBackend]
/// false: `ENVIRONMENT` is `development` and `BASE_URL` is empty in `.env`
/// and in `--dart-define`. Otherwise the real `AuthRemoteDataSourceImpl` is
/// used.
///
/// Setting `BASE_URL`, building for staging or production, or building in
/// profile or release mode turns it off, so it cannot ship by accident. To
/// remove it, follow "Signing In Before You Have a Backend" in
/// `docs/guides/onboarding/getting-started.md`.
abstract final class DemoAuth {
  /// The account the login screen offers while demo mode is on.
  static const String email = 'demo@example.com';

  /// Password of [email]; it satisfies the login form's validators.
  static const String password = 'demo1234';

  /// Forces demo mode on or off, for tests. `null` applies the rule: a debug
  /// build without [AppConfig.hasBackend].
  @visibleForTesting
  static bool? debugEnabledOverride;

  /// Whether this build uses the demo sign-in.
  static bool get enabled =>
      debugEnabledOverride ?? (kDebugMode && !AppConfig.hasBackend);

  /// The rule behind [enabled], with every input explicit.
  static bool isEnabledFor({
    required bool debugBuild,
    required String environment,
    required String baseUrl,
  }) =>
      debugBuild &&
      !AppConfig.hasBackendFor(environment: environment, baseUrl: baseUrl);
}

/// An [AuthRemoteDataSource] that never touches the network.
///
/// [DemoAuth.email] / [DemoAuth.password] always signs in, and registering
/// adds an account for this run of the app. A wrong password is an
/// [AuthException], which the repository reports exactly like a 401 from a
/// real server.
class DemoAuthRemoteDataSource implements AuthRemoteDataSource {
  /// Creates the data source with the demo account registered.
  DemoAuthRemoteDataSource()
    : _accounts = {
        DemoAuth.email: (password: DemoAuth.password, name: 'Demo User'),
      };

  final Map<String, ({String password, String? name})> _accounts;
  final Map<String, String> _emailByRefreshToken = {};
  var _issued = 0;

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null || account.password != password) {
      throw const AuthException('Invalid email or password');
    }
    return _signIn(key, account.name);
  }

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async {
    final key = email.trim().toLowerCase();
    _accounts[key] = (password: password, name: name);
    return _signIn(key, name);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    final email = _emailByRefreshToken.remove(refreshToken);
    if (email == null) {
      throw const AuthException('Demo session expired');
    }
    return _signIn(email, _accounts[email]?.name);
  }

  AuthResponseModel _signIn(String email, String? name) {
    _issued++;
    final refresh = 'demo-refresh-$_issued';
    _emailByRefreshToken[refresh] = email;
    return AuthResponseModel(
      user: UserModel(id: 'demo:$email', email: email, name: name),
      token: 'demo-access-$_issued',
      refreshToken: refresh,
    );
  }
}
