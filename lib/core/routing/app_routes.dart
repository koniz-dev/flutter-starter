// Core route constants are intentionally centralized here for copy/paste usage.
// ignore_for_file: public_member_api_docs

/// Application route paths and names.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';

  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:taskId';

  static const String featureFlagsDebug = '/feature-flags-debug';

  static const String homeName = 'home';
  static const String loginName = 'login';
  static const String registerName = 'register';

  static const String tasksName = 'tasks';
  static const String taskDetailName = 'task-detail';

  static const String featureFlagsDebugName = 'feature-flags-debug';
}

/// Route parameter keys
class RouteParams {
  RouteParams._();

  static const String taskId = 'taskId';
}

/// Query parameter keys
class RouteQueryParams {
  RouteQueryParams._();
}
