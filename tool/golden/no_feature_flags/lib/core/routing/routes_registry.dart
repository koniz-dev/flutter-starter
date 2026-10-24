// Strip variant `--remove-feature-flags`: tasks sample kept, feature flags
// route module dropped along with the feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/features/auth/routing/auth_routes.dart';
import 'package:flutter_starter/features/home/routing/home_routes.dart';
import 'package:flutter_starter/features/tasks/routing/tasks_routes.dart';
import 'package:go_router/go_router.dart';

/// Composes the app route tree from per-feature route modules.
///
/// Every screen the app ships reaches the tree through here. A route constant
/// or navigation helper that no module registers is a 404 waiting to happen,
/// so add the feature's `routing/` module here in the same change that adds
/// the constant.
///
/// Screens that must never ship in production - ones that change app state
/// for testing, such as a flag-override screen - go in
/// [_buildDebugRoutes] instead. That block is registered only while
/// [AppConfig.enableDebugFeatures] holds: true in development, false in
/// staging and production unless `ENABLE_DEBUG_FEATURES` says otherwise.
/// Where it is not registered, its paths are unknown routes, deep links
/// included.
///
/// [debugRoutes] replaces the [AppConfig] check, for tests.
List<RouteBase> buildAppRoutes(Ref ref, {bool? debugRoutes}) {
  return <RouteBase>[
    ...buildAuthRoutes(ref),
    ...buildTasksRoutes(ref),
    if (debugRoutes ?? AppConfig.enableDebugFeatures) ..._buildDebugRoutes(ref),
    buildHomeRoute(ref),
  ];
}

/// Debug-only route modules; see [buildAppRoutes].
List<RouteBase> _buildDebugRoutes(Ref ref) => const <RouteBase>[
  // Add your debug-only route modules here.
];
