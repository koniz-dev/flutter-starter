// Strip variant `--remove-tasks`: feature flags sample kept, tasks
// navigation helpers dropped along with the feature.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:go_router/go_router.dart';

/// Navigation extensions for GoRouter
///
/// This extension provides convenient methods for navigation using GoRouter.
/// It offers type-safe navigation methods that use route constants from
/// [AppRoutes].
///
/// **Usage:**
/// ```dart
/// // Basic navigation
/// context.goToHome();
/// context.goToLogin();
///
/// // Navigation with parameters (example)
/// context.goToProfile(userId: '123');
///
/// // Pop navigation
/// context.popRoute();
/// ```
extension NavigationExtensions on BuildContext {
  /// Navigate to home screen
  void goToHome() => go(AppRoutes.home);

  /// Navigate to login screen
  void goToLogin() => go(AppRoutes.login);

  /// Navigate to register screen
  void goToRegister() => go(AppRoutes.register);

  /// Navigate to the feature flags debug screen
  void goToFeatureFlagsDebug() => go(AppRoutes.featureFlagsDebug);

  /// Push a new route (adds to navigation stack)
  void pushRoute(String location, {Object? extra}) {
    unawaited(push(location, extra: extra));
  }

  /// Push a named route
  void pushNamedRoute(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) {
    unawaited(
      pushNamed(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
      ),
    );
  }

  /// Replace current route
  void replaceRoute(String location, {Object? extra}) {
    replace(location, extra: extra);
  }

  /// Replace current route with named route
  void replaceNamedRoute(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) {
    replaceNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }

  /// Pop current route
  void popRoute<T>([T? result]) {
    pop<T>(result);
  }

  /// Pop until [location] is the top of the stack.
  ///
  /// Reads the location from the router rather than from `this`.
  /// `GoRouterState.of(this)` is the state of the caller's own `ModalRoute`,
  /// and this element is not rebuilt during a synchronous loop, so it is a
  /// loop invariant: the old form either stopped on iteration 0 or popped the
  /// whole stack.
  void popUntilRoute(String location) {
    final router = GoRouter.of(this);
    while (router.state.matchedLocation != location && router.canPop()) {
      final before = router.state.matchedLocation;
      router.pop();
      // A route with an `onExit` guard defers its pop, leaving the match list
      // untouched. Without this the loop would spin forever.
      if (router.state.matchedLocation == before) {
        break;
      }
    }
  }

  /// Check if can pop
  bool canPopRoute() => canPop();

  /// Go back if possible, otherwise go to home
  void popOrGoToHome() {
    if (canPop()) {
      pop();
    } else {
      goToHome();
    }
  }
}
