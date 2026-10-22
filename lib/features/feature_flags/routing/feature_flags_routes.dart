import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:go_router/go_router.dart';

/// Builds the feature-flags debug route (protected by the auth redirect).
///
/// The route exists only while [AppConfig.enableDebugFeatures] holds: true in
/// development, false in staging and production unless
/// `ENABLE_DEBUG_FEATURES` says otherwise. The screen writes a local override
/// for any flag, `enable_premium_features` included, so registering it in
/// every build let any signed-in user of a production build flip flags by
/// deep link, or by URL on web. Where it is
/// not registered, `/feature-flags-debug` is an unknown route.
///
/// [enabled] replaces the [AppConfig] check, for tests.
List<RouteBase> buildFeatureFlagsRoutes(Ref ref, {bool? enabled}) {
  if (!(enabled ?? AppConfig.enableDebugFeatures)) return const <RouteBase>[];
  return <RouteBase>[
    GoRoute(
      path: AppRoutes.featureFlagsDebug,
      name: AppRoutes.featureFlagsDebugName,
      builder: (context, state) => const FeatureFlagsDebugScreen(),
    ),
  ];
}
