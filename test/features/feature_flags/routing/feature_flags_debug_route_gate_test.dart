// The feature-flags debug screen must not ship in production.
//
// The screen writes a local override for any flag, `enable_premium_features`
// included, and `/feature-flags-debug` used to be registered in every build,
// so any signed-in user of a production build could reach it by deep link, or
// by URL on web. It now sits in the route registry's debug-only block, which
// is registered only when `AppConfig.enableDebugFeatures` holds - false in
// production unless `ENABLE_DEBUG_FEATURES` says otherwise.
//
// Run this file twice to see both environments:
//   flutter test <this file>
//   flutter test <this file> --dart-define=ENVIRONMENT=production

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every path in [routes], nested ones included.
List<String> _paths(List<RouteBase> routes) => [
  for (final route in routes) ...[
    if (route is GoRoute) route.path,
    ..._paths(route.routes),
  ],
];

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  List<String> appPaths({bool? debugRoutes}) => _paths(
    container.read(
      Provider<List<RouteBase>>(
        (ref) => buildAppRoutes(ref, debugRoutes: debugRoutes),
      ),
    ),
  );

  test('the route is registered only when debug routes are on', () {
    expect(appPaths(debugRoutes: true), contains(AppRoutes.featureFlagsDebug));
    expect(
      appPaths(debugRoutes: false),
      isNot(contains(AppRoutes.featureFlagsDebug)),
    );
  });

  test('turning debug routes off removes nothing else', () {
    final on = appPaths(debugRoutes: true)..remove(AppRoutes.featureFlagsDebug);
    expect(appPaths(debugRoutes: false), on);
  });

  test('by default it follows AppConfig.enableDebugFeatures', () {
    expect(
      appPaths().contains(AppRoutes.featureFlagsDebug),
      AppConfig.enableDebugFeatures,
    );
  });

  test('the app route tree in this run matches the environment '
      '(${AppConfig.environment})', () {
    // A .env that set ENABLE_DEBUG_FEATURES would make this assert the
    // override instead of the environment default; the test VM loads none.
    expect(EnvConfig.isInitialized, isFalse);
    expect(EnvConfig.has('ENABLE_DEBUG_FEATURES'), isFalse);

    final paths = appPaths();
    // The line is the evidence for criterion 1 when run with and without
    // --dart-define=ENVIRONMENT=production.
    // ignore: avoid_print
    print(
      'VP environment=${AppConfig.environment} '
      'enableDebugFeatures=${AppConfig.enableDebugFeatures} '
      'paths=$paths',
    );

    if (AppConfig.isProduction) {
      expect(AppConfig.enableDebugFeatures, isFalse);
      expect(paths, isNot(contains(AppRoutes.featureFlagsDebug)));
    } else if (AppConfig.isDevelopment) {
      expect(AppConfig.enableDebugFeatures, isTrue);
      expect(paths, contains(AppRoutes.featureFlagsDebug));
    }
    // The rest of the tree does not depend on the environment.
    expect(paths, containsAll(<String>[AppRoutes.login, AppRoutes.home]));
  });
}
