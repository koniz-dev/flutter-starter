/// Application route paths and names
///
/// This file defines all route paths and names as constants for type-safe
/// routing. Use these constants instead of hardcoded strings to prevent typos
/// and ensure consistency across the application.
class AppRoutes {
  AppRoutes._(); // Private constructor to prevent instantiation

  // Route paths
  /// Home route path
  static const String home = '/';

  /// Login route path
  static const String login = '/login';

  /// Register route path
  static const String register = '/register';

  /// Feature flags debug route path (nested route)
  static const String featureFlagsDebug = '/feature-flags-debug';

  // Route names (for named navigation)
  /// Home route name
  static const String homeName = 'home';

  /// Login route name
  static const String loginName = 'login';

  /// Register route name
  static const String registerName = 'register';

  /// Feature flags debug route name
  static const String featureFlagsDebugName = 'feature-flags-debug';

  // Example routes with parameters (for future use)
  // static const String profile = '/profile/:userId';
  // static const String profileName = 'profile';
  // static const String product = '/product/:productId';
  // static const String productName = 'product';
}

/// Route parameter keys
///
/// Use these constants when extracting parameters from route state
class RouteParams {
  RouteParams._(); // Private constructor to prevent instantiation

  // Example parameter keys (for future use)
  // static const String userId = 'userId';
  // static const String productId = 'productId';
}

/// Query parameter keys
///
/// Use these constants when extracting query parameters from route state
class RouteQueryParams {
  RouteQueryParams._(); // Private constructor to prevent instantiation

  // Example query parameter keys (for future use)
  // static const String tab = 'tab';
  // static const String filter = 'filter';
}
