import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
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
