import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/auth/routing/auth_routes.dart';
import 'package:flutter_starter/features/home/routing/home_routes.dart';
import 'package:go_router/go_router.dart';

/// Composes the app route tree from per-feature route modules.
///
/// Stripped baseline: auth + home only.
List<RouteBase> buildAppRoutes(Ref ref) {
  return <RouteBase>[...buildAuthRoutes(ref), buildHomeRoute(ref)];
}
