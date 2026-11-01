import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/routing/home_destination.dart';
import 'package:flutter_starter/core/routing/session_status.dart';
import 'package:flutter_starter/features/auth/routing/auth_routes.dart';
import 'package:flutter_starter/features/feature_flags/routing/feature_flags_routes.dart';
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
List<RouteBase> _buildDebugRoutes(Ref ref) => <RouteBase>[
  ...buildFeatureFlagsRoutes(ref),
];

/// The entries the home screen lists, one per registered feature that
/// declares a [HomeDestination].
///
/// Keep it beside [buildAppRoutes]: an entry whose route is not registered
/// is a dead link. Debug-only destinations follow the same rule as the
/// debug routes, and [debugRoutes] replaces the [AppConfig] check, for tests.
List<HomeDestination> buildHomeDestinations({
  bool? debugRoutes,
}) => <HomeDestination>[
  tasksHomeDestination,
  if (debugRoutes ?? AppConfig.enableDebugFeatures) ..._debugHomeDestinations(),
];

/// Debug-only home entries; see [buildHomeDestinations].
List<HomeDestination> _debugHomeDestinations() => <HomeDestination>[
  featureFlagsHomeDestination,
];

/// What the home screen reads; see [buildHomeDestinations].
final Provider<List<HomeDestination>> homeDestinationsProvider =
    Provider<List<HomeDestination>>((ref) => buildHomeDestinations());

/// The session state the redirect in `app_router.dart` reads.
///
/// Composed here, beside the routes, so the router imports no feature: the
/// feature that owns sign-in supplies it, as it supplies its routes.
final NotifierProvider<Notifier<SessionStatus>, SessionStatus>
sessionStatusProvider =
    NotifierProvider<Notifier<SessionStatus>, SessionStatus>(
      AuthSessionStatusNotifier.new,
    );
