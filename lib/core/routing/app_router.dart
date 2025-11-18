import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/shared/screens/home_screen.dart';
import 'package:go_router/go_router.dart';

/// Provider for GoRouter instance
///
/// This provider creates a [GoRouter] instance that:
/// - Integrates with Riverpod for dependency injection
/// - Handles authentication-based routing (protected routes)
/// - Supports deep linking
/// - Provides type-safe route definitions
///
/// The router automatically redirects unauthenticated users to the login screen
/// and authenticated users away from auth screens.
///
/// **Note:** This provider uses `refreshListenable` to reactively update
/// routing when authentication state changes, without recreating the router
/// instance.
final goRouterProvider = Provider<GoRouter>((ref) {
  // Create the listenable that will notify router of auth state changes
  final authStateNotifier = _AuthStateNotifier(ref);

  // Create router configuration
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true, // Enable debug logging in development
    routes: [
      // Public routes (accessible without authentication)
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Protected routes (require authentication)
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomeScreen(),
        routes: [
          // Nested routes example
          GoRoute(
            path: 'feature-flags-debug',
            name: AppRoutes.featureFlagsDebugName,
            builder: (context, state) => const FeatureFlagsDebugScreen(),
          ),
        ],
      ),
    ],

    // Redirect logic for authentication-based routing
    // This function is called whenever navigation occurs or auth state changes
    redirect: (BuildContext context, GoRouterState state) {
      // Read current auth state (safe because redirect is synchronous)
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.user != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      // Redirect to login if not authenticated and trying to access protected
      // route
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      // Redirect to home if authenticated and trying to access auth routes
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.home;
      }

      // No redirect needed
      return null;
    },

    // Refresh router when auth state changes
    // The router will call redirect() again when this notifier fires
    refreshListenable: authStateNotifier,
  );
});

/// Listenable wrapper for auth state changes
///
/// This allows GoRouter to reactively update when auth state changes.
/// When auth state changes, this notifier fires, causing GoRouter to
/// re-evaluate the redirect function.
///
/// **Implementation Note:** This uses `ref.listen` to watch auth state changes
/// and notify the router. The router will then call `redirect()` again to check
/// if navigation should occur.
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    // Listen to auth state changes and notify router
    // This will trigger GoRouter's redirect logic to re-evaluate
    _ref.listen<AuthState>(
      authNotifierProvider,
      (previous, next) {
        // Only notify if authentication status actually changed
        // This prevents unnecessary redirect evaluations
        final wasAuthenticated = previous?.user != null;
        final isAuthenticated = next.user != null;
        
        if (wasAuthenticated != isAuthenticated) {
          // Notify router of state change to trigger redirect
          notifyListeners();
        }
      },
    );
  }

  final Ref _ref;

  @override
  void dispose() {
    // Clean up is handled automatically by Riverpod
    // The ref.listen subscription is automatically cancelled when the provider
    // is disposed
    super.dispose();
  }
}
