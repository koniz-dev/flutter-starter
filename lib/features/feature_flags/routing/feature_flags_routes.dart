import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:go_router/go_router.dart';

/// Builds the feature-flags debug route (protected by the auth redirect).
List<RouteBase> buildFeatureFlagsRoutes(Ref ref) {
  return <RouteBase>[
    GoRoute(
      path: AppRoutes.featureFlagsDebug,
      name: AppRoutes.featureFlagsDebugName,
      builder: (context, state) => const FeatureFlagsDebugScreen(),
    ),
  ];
}
