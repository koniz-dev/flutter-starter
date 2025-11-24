import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes', () {
    test('should have home route path', () {
      expect(AppRoutes.home, isA<String>());
      expect(AppRoutes.home, '/');
    });

    test('should have login route path', () {
      expect(AppRoutes.login, isA<String>());
      expect(AppRoutes.login, '/login');
    });

    test('should have register route path', () {
      expect(AppRoutes.register, isA<String>());
      expect(AppRoutes.register, '/register');
    });

    test('should have featureFlagsDebug route path', () {
      expect(AppRoutes.featureFlagsDebug, isA<String>());
      expect(AppRoutes.featureFlagsDebug, '/feature-flags-debug');
    });

    test('should have tasks route path', () {
      expect(AppRoutes.tasks, isA<String>());
      expect(AppRoutes.tasks, '/tasks');
    });

    test('should have taskDetail route path', () {
      expect(AppRoutes.taskDetail, isA<String>());
      expect(AppRoutes.taskDetail, '/tasks/:taskId');
    });

    test('should have home route name', () {
      expect(AppRoutes.homeName, isA<String>());
      expect(AppRoutes.homeName, 'home');
    });

    test('should have login route name', () {
      expect(AppRoutes.loginName, isA<String>());
      expect(AppRoutes.loginName, 'login');
    });

    test('should have register route name', () {
      expect(AppRoutes.registerName, isA<String>());
      expect(AppRoutes.registerName, 'register');
    });

    test('should have featureFlagsDebug route name', () {
      expect(AppRoutes.featureFlagsDebugName, isA<String>());
      expect(AppRoutes.featureFlagsDebugName, 'feature-flags-debug');
    });

    test('should have tasks route name', () {
      expect(AppRoutes.tasksName, isA<String>());
      expect(AppRoutes.tasksName, 'tasks');
    });

    test('should have taskDetail route name', () {
      expect(AppRoutes.taskDetailName, isA<String>());
      expect(AppRoutes.taskDetailName, 'task-detail');
    });

    test('should have all route paths starting with /', () {
      expect(AppRoutes.home, startsWith('/'));
      expect(AppRoutes.login, startsWith('/'));
      expect(AppRoutes.register, startsWith('/'));
      expect(AppRoutes.featureFlagsDebug, startsWith('/'));
      expect(AppRoutes.tasks, startsWith('/'));
      expect(AppRoutes.taskDetail, startsWith('/'));
    });

    test('should have all route names as non-empty strings', () {
      expect(AppRoutes.homeName, isNotEmpty);
      expect(AppRoutes.loginName, isNotEmpty);
      expect(AppRoutes.registerName, isNotEmpty);
      expect(AppRoutes.featureFlagsDebugName, isNotEmpty);
      expect(AppRoutes.tasksName, isNotEmpty);
      expect(AppRoutes.taskDetailName, isNotEmpty);
    });

    test('should have unique route paths', () {
      final paths = [
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.featureFlagsDebug,
        AppRoutes.tasks,
        AppRoutes.taskDetail,
      ];
      expect(paths.toSet().length, paths.length);
    });

    test('should have unique route names', () {
      final names = [
        AppRoutes.homeName,
        AppRoutes.loginName,
        AppRoutes.registerName,
        AppRoutes.featureFlagsDebugName,
        AppRoutes.tasksName,
        AppRoutes.taskDetailName,
      ];
      expect(names.toSet().length, names.length);
    });

    test('should have route paths without trailing slashes (except home)', () {
      expect(AppRoutes.login, isNot(endsWith('/')));
      expect(AppRoutes.register, isNot(endsWith('/')));
      expect(AppRoutes.featureFlagsDebug, isNot(endsWith('/')));
      expect(AppRoutes.tasks, isNot(endsWith('/')));
      expect(AppRoutes.taskDetail, isNot(endsWith('/')));
    });

    test('should have taskDetail with parameter placeholder', () {
      expect(AppRoutes.taskDetail, contains(':taskId'));
    });
  });

  group('RouteParams', () {
    test('should have taskId parameter key', () {
      expect(RouteParams.taskId, isA<String>());
      expect(RouteParams.taskId, 'taskId');
    });

    test('should have taskId as non-empty string', () {
      expect(RouteParams.taskId, isNotEmpty);
    });

    test('should have taskId matching route parameter', () {
      expect(AppRoutes.taskDetail, contains(':${RouteParams.taskId}'));
    });
  });

  group('RouteQueryParams', () {
    test('should be accessible', () {
      expect(RouteQueryParams, isNotNull);
    });
  });
}

