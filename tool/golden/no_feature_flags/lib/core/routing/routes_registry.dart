// Strip variant `--remove-feature-flags`: tasks sample kept, feature flags
// route module dropped along with the feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
List<RouteBase> buildAppRoutes(Ref ref) {
  return <RouteBase>[
    ...buildAuthRoutes(ref),
    ...buildTasksRoutes(ref),
    buildHomeRoute(ref),
  ];
}
