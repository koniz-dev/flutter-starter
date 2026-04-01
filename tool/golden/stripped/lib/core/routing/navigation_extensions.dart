import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:go_router/go_router.dart';

/// Navigation extensions for GoRouter (stripped baseline).
extension NavigationExtensions on BuildContext {
  /// Navigate to home screen.
  void goToHome() => go(AppRoutes.home);

  /// Navigate to login screen.
  void goToLogin() => go(AppRoutes.login);

  /// Navigate to register screen.
  void goToRegister() => go(AppRoutes.register);

  /// Push a new route (adds to navigation stack).
  void pushRoute(String location, {Object? extra}) {
    unawaited(push(location, extra: extra));
  }

  /// Push a named route.
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

  /// Replace current route.
  void replaceRoute(String location, {Object? extra}) {
    replace(location, extra: extra);
  }

  /// Replace current route with named route.
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

  /// Pop current route.
  void popRoute<T>([T? result]) {
    pop<T>(result);
  }

  /// Pop until a specific route.
  void popUntilRoute(String location) {
    while (canPop()) {
      if (GoRouterState.of(this).matchedLocation == location) {
        break;
      }
      pop();
    }
  }

  /// Whether the navigator can pop.
  bool canPopRoute() => canPop();

  /// Go back if possible, otherwise go to home.
  void popOrGoToHome() {
    if (canPop()) {
      pop();
    } else {
      goToHome();
    }
  }
}
