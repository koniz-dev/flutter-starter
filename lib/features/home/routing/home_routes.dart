import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:go_router/go_router.dart';

/// Builds the Home (protected) route, optionally with nested child routes.
GoRoute buildHomeRoute(
  Ref ref, {
  List<RouteBase> children = const <RouteBase>[],
}) {
  return GoRoute(
    path: AppRoutes.home,
    name: AppRoutes.homeName,
    builder: (context, state) => const HomeScreen(),
    routes: children,
  );
}
