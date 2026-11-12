import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/{{feature_name}}/presentation/screens/{{feature_name}}_screen.dart';
import 'package:go_router/go_router.dart';

/// Path of the {{class_name}} screen.
///
/// Move this and [{{class_name.camelCase()}}RouteName] into `AppRoutes`
/// (`lib/core/routing/app_routes.dart`) when you register the route, so
/// navigation uses the same constants as every other screen.
const String {{class_name.camelCase()}}RoutePath = '/{{feature_name.paramCase()}}';

/// Name of the {{class_name}} route.
const String {{class_name.camelCase()}}RouteName = '{{feature_name.paramCase()}}';

/// Builds the {{class_name}} route, reachable once signed in.
///
/// Nothing registers it yet: add `build{{class_name}}Route(ref),` to
/// `buildAppRoutes` in `lib/core/routing/routes_registry.dart`. A route that
/// is not registered there is a 404.
GoRoute build{{class_name}}Route(Ref ref) {
  return GoRoute(
    path: {{class_name.camelCase()}}RoutePath,
    name: {{class_name.camelCase()}}RouteName,
    builder: (context, state) =>
        {{class_name}}Screen(id: state.uri.queryParameters['id'] ?? '1'),
  );
}
