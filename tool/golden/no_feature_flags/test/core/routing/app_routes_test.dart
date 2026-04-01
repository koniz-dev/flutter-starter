import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes', () {
    test('should have core route paths', () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.login, '/login');
      expect(AppRoutes.register, '/register');
    });

    test('should have tasks route paths', () {
      expect(AppRoutes.tasks, '/tasks');
      expect(AppRoutes.taskDetail, '/tasks/:taskId');
    });

    test('should have route names', () {
      expect(AppRoutes.homeName, 'home');
      expect(AppRoutes.loginName, 'login');
      expect(AppRoutes.registerName, 'register');
      expect(AppRoutes.tasksName, 'tasks');
      expect(AppRoutes.taskDetailName, 'task-detail');
    });
  });
}
