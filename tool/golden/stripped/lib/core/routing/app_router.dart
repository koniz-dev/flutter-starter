import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_logging.dart';
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
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.user != null;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    refreshListenable: authStateNotifier,
  );
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
  }

  final Ref _ref;
}
