import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/session_status.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:go_router/go_router.dart';

/// Builds the authentication routes (public).
List<RouteBase> buildAuthRoutes(Ref ref) {
  return <RouteBase>[
    GoRoute(
      path: AppRoutes.login,
      name: AppRoutes.loginName,
      builder: (context, state) => LoginScreen(
        redirect: state.uri.queryParameters[RouteQueryParams.redirect],
      ),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: AppRoutes.registerName,
      builder: (context, state) => RegisterScreen(
        redirect: state.uri.queryParameters[RouteQueryParams.redirect],
      ),
    ),
  ];
}

/// The session as the router's redirect sees it; see [SessionStatus].
///
/// Kept current with `ref.listen`, not `ref.watch`: a listener still fires
/// while nothing watches the router (a widget test that only reads it), where
/// a watched provider would be paused and miss the change. Listening to
/// [sessionRestorationProvider] also starts the restore. The auth state alone
/// would not be enough: a restore that finds no session leaves it untouched,
/// so without the second listener the app would sit on the held location
/// forever instead of falling through to `/login`.
class AuthSessionStatusNotifier extends Notifier<SessionStatus> {
  @override
  SessionStatus build() {
    ref
      ..listen(
        authNotifierProvider.select((auth) => auth.user != null),
        (_, _) => state = _current(),
      )
      ..listen(
        sessionRestorationProvider.select((restore) => restore.isLoading),
        (_, _) => state = _current(),
      );
    return _current();
  }

  SessionStatus _current() {
    if (ref.read(authNotifierProvider).user != null) {
      return SessionStatus.signedIn;
    }
    return ref.read(sessionRestorationProvider).isLoading
        ? SessionStatus.restoring
        : SessionStatus.signedOut;
  }
}
