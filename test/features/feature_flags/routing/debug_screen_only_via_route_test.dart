// The flag-override screen can flip any flag, so it must be reachable only
// through the debug-only route block in routes_registry.dart, which production
// builds do not register. A direct construction anywhere else - a
// `MaterialPageRoute` from some other screen, say - would go around that gate.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _routeModule =
    'lib/features/feature_flags/routing/feature_flags_routes.dart';
const _screen =
    'lib/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';

void main() {
  test('only the route module constructs FeatureFlagsDebugScreen', () {
    final constructors = RegExp(r'\bFeatureFlagsDebugScreen\s*\(');
    final offenders = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            entity.path != _routeModule &&
            entity.path != _screen &&
            constructors.hasMatch(entity.readAsStringSync()))
          entity.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'open the screen by route (AppRoutes.featureFlagsDebug), so the '
          'debug-only gate in routes_registry.dart applies',
    );
  });
}
