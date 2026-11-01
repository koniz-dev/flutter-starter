import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every full path in [routes], nested ones joined to their parent.
List<String> _paths(List<RouteBase> routes, [String parent = '']) => [
  for (final route in routes)
    if (route is GoRoute) ...[
      _join(parent, route.path),
      ..._paths(route.routes, _join(parent, route.path)),
    ] else
      ..._paths(route.routes, parent),
];

String _join(String parent, String path) =>
    path.startsWith('/') ? path : '${parent == '/' ? '' : parent}/$path';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  for (final debugRoutes in [true, false]) {
    test('every home destination opens a registered route '
        '(debug routes ${debugRoutes ? 'on' : 'off'})', () {
      final paths = _paths(
        container.read(
          Provider<List<RouteBase>>(
            (ref) => buildAppRoutes(ref, debugRoutes: debugRoutes),
          ),
        ),
      );
      final destinations = buildHomeDestinations(debugRoutes: debugRoutes);

      for (final destination in destinations) {
        expect(paths, contains(destination.location), reason: destination.id);
      }
      expect(
        destinations.map((d) => d.id).toSet(),
        hasLength(destinations.length),
        reason: 'ids key the home entries, so they must be unique',
      );
    });
  }

  test('the home screen reads the registry by default', () {
    expect(
      container.read(homeDestinationsProvider).map((d) => d.id),
      buildHomeDestinations().map((d) => d.id),
    );
  });
}
