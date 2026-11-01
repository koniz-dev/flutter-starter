import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/home_destination.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:go_router/go_router.dart';

/// Builds the feature-flags debug route (protected by the auth redirect).
///
/// The screen writes a local override for any flag, `enable_premium_features`
/// included, so it must not ship in production: `routes_registry.dart`
/// registers this module in its debug-only block, which exists only while
/// `AppConfig.enableDebugFeatures` holds.
List<RouteBase> buildFeatureFlagsRoutes(Ref ref) {
  return <RouteBase>[
    GoRoute(
      path: AppRoutes.featureFlagsDebug,
      name: AppRoutes.featureFlagsDebugName,
      builder: (context, state) => const FeatureFlagsDebugScreen(),
    ),
  ];
}

/// The home screen's entry to the flag-override screen. Debug-only, like the
/// route it opens.
final HomeDestination featureFlagsHomeDestination = HomeDestination(
  id: 'feature_flags',
  icon: Icons.flag_outlined,
  label: (l10n) => l10n.featureFlagsDebug,
  location: AppRoutes.featureFlagsDebug,
);
