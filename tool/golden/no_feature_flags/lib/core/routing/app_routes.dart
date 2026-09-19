// Strip variant `--remove-feature-flags`: tasks sample kept, feature flags
// route constants dropped along with the feature.
// ignore_for_file: public_member_api_docs

/// Application route paths and names.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';

  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:taskId';

  static const String homeName = 'home';
  static const String loginName = 'login';
  static const String registerName = 'register';

  static const String tasksName = 'tasks';
  static const String taskDetailName = 'task-detail';
}

/// Route parameter keys
class RouteParams {
  RouteParams._();

  static const String taskId = 'taskId';
}

/// Query parameter keys
class RouteQueryParams {
  RouteQueryParams._();

  /// Destination the auth guard bounced away from, carried on `/login` so a
  /// deep link survives the login round trip.
  static const String redirect = 'redirect';
}
