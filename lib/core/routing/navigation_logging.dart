import 'package:flutter/material.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:go_router/go_router.dart';

/// Navigator observer for logging navigation events
///
/// This observer logs all navigation events including:
/// - Route pushes
/// - Route pops
/// - Route replacements
/// - Route removals
///
/// Usage:
/// ```dart
/// final router = GoRouter(
///   observers: [
///     NavigationLoggingObserver(
///       loggingService: ref.read(loggingServiceProvider),
///     ),
///   ],
///   // ... other configuration
/// );
/// ```
class NavigationLoggingObserver extends NavigatorObserver {
  /// Creates a [NavigationLoggingObserver] with the given [loggingService]
  NavigationLoggingObserver({
    required LoggingService loggingService,
  }) : _loggingService = loggingService;

  /// Logging service instance
  final LoggingService _loggingService;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigation(
      'Route Pushed',
      route,
      previousRoute,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logNavigation(
      'Route Popped',
      route,
      previousRoute,
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logNavigation(
      'Route Removed',
      route,
      previousRoute,
    );
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logNavigation(
        'Route Replaced',
        newRoute,
        oldRoute,
      );
    }
  }

  /// Log a navigation event
  void _logNavigation(
    String event,
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    final context = <String, dynamic>{
      'routeName': route.settings.name,
      'routePath': _getRoutePath(route),
      if (previousRoute != null)
        'previousRouteName': previousRoute.settings.name,
      if (previousRoute != null)
        'previousRoutePath': _getRoutePath(previousRoute),
    };

    _loggingService.info(
      'Navigation: $event',
      context: context,
    );
  }

  /// Get route path from route object
  String _getRoutePath(Route<dynamic> route) {
    // Try to get path from route settings name (GoRouter sets this)
    if (route.settings.name != null) {
      return route.settings.name!;
    }

    // Try to get from route settings arguments if available
    if (route.settings.arguments is Map) {
      final args = route.settings.arguments! as Map;
      if (args.containsKey('uri')) {
        return args['uri'].toString();
      }
    }

    // Fallback to route toString (removes 'Route' suffix if present)
    final routeString = route.toString();
    return routeString.replaceAll(RegExp('Route<.*>'), '').trim();
  }
}

/// Extension for GoRouter to add navigation logging
extension GoRouterLoggingExtension on GoRouter {
  /// Log navigation to a specific location
  void logNavigation(String location) {
    // This can be called before navigation to log the intent
    // The actual navigation will be logged by NavigationLoggingObserver
  }
}
