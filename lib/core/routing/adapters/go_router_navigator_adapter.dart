import 'package:flutter_starter/core/contracts/navigation_contracts.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:go_router/go_router.dart';

/// GoRouter implementation of [AppNavigator].
class GoRouterNavigatorAdapter implements AppNavigator {
  /// Creates an adapter around the given [GoRouter] instance.
  GoRouterNavigatorAdapter(this._router);

  final GoRouter _router;

  @override
  Future<void> toHome() async => _router.go(AppRoutes.home);

  @override
  Future<void> toLogin() async => _router.go(AppRoutes.login);

  @override
  Future<void> toRegister() async => _router.go(AppRoutes.register);

  @override
  Future<void> toTasks() async => _router.go('/tasks');

  @override
  Future<void> toTaskDetail(String taskId) async =>
      _router.go('/tasks/$taskId');

  @override
  Future<void> push(String location, {Object? extra}) async {
    await _router.push(location, extra: extra);
  }

  @override
  Future<void> replace(String location, {Object? extra}) async {
    await _router.pushReplacement(location, extra: extra);
  }

  @override
  Future<void> back<T>([T? result]) async {
    if (_router.canPop()) {
      _router.pop<T>(result);
      return;
    }
    _router.go(AppRoutes.login);
  }
}
