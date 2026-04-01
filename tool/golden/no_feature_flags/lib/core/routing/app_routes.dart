// Variant baseline: keep routes minimal; focus is on wiring.
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

class RouteParams {
  RouteParams._();
  static const String taskId = 'taskId';
}

class RouteQueryParams {
  RouteQueryParams._();
}
