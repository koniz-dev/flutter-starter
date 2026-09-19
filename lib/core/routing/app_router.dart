import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_logging.dart';
import 'package:flutter_starter/core/routing/route_not_found_screen.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Provider for GoRouter instance (stripped baseline).
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final authStateNotifier = _AuthStateNotifier(ref);
  final loggingService = ref.read(loggingServiceProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: kDebugMode,
    observers: [NavigationLoggingObserver(loggingService: loggingService)],
    routes: buildAppRoutes(ref),
    // Without this, an unmatched location renders go_router's own red debug
    // page - framework exception and stack trace, at the user.
    errorBuilder: (context, state) =>
        RouteNotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final restoration = ref.read(sessionRestorationProvider);
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.user != null;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      // Three states, not two. While the persisted session is still being
      // read back, "not authenticated yet" is not the same as "logged out":
      // bouncing here would send every returning user to /login for a frame
      // and snap them back. Hold the requested location instead - the
      // refreshListenable below re-runs this the moment restore settles.
      if (!isAuthenticated && restoration.isLoading) {
        return null;
      }

      if (!isAuthenticated && !isAuthRoute) {
        return _loginPreserving(state.uri);
      }

      if (isAuthenticated && isAuthRoute) {
        return _destinationAfterAuth(state.uri);
      }

      return null;
    },
    refreshListenable: authStateNotifier,
  );
}

/// `/login`, carrying [from] so the guard can hand the user back afterwards.
///
/// A plain cold start on `/` gets no query string: there is nothing to
/// remember, and `?redirect=%2F` is just noise in the address bar.
String _loginPreserving(Uri from) {
  if (from.path == AppRoutes.home && !from.hasQuery) {
    return AppRoutes.login;
  }
  return Uri(
    path: AppRoutes.login,
    queryParameters: {RouteQueryParams.redirect: from.toString()},
  ).toString();
}

/// Where an authenticated user standing on an auth route should land.
///
/// The `redirect` query parameter is attacker-influenceable (it arrives in a
/// URL), so only same-app absolute paths are honoured: anything with a scheme
/// or an authority would be an open redirect, and an auth route would loop.
String _destinationAfterAuth(Uri current) {
  final target = current.queryParameters[RouteQueryParams.redirect];
  if (target == null || target.isEmpty) {
    return AppRoutes.home;
  }

  final parsed = Uri.tryParse(target);
  if (parsed == null ||
      parsed.hasScheme ||
      parsed.hasAuthority ||
      !parsed.path.startsWith('/') ||
      parsed.path == AppRoutes.login ||
      parsed.path == AppRoutes.register) {
    return AppRoutes.home;
  }

  return target;
}

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    _ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      final wasAuthenticated = previous?.user != null;
      final isAuthenticated = next.user != null;

      if (wasAuthenticated != isAuthenticated) {
        notifyListeners();
      }
    });

    // Starts the restore (listening initialises the provider) and re-runs the
    // redirect when it settles. The auth listener above is not enough: a
    // restore that finds no session leaves the auth state untouched, so
    // without this the app would sit on the held location forever instead of
    // falling through to /login.
    _ref.listen<AsyncValue<void>>(sessionRestorationProvider, (previous, next) {
      if (previous?.isLoading != next.isLoading) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
}
