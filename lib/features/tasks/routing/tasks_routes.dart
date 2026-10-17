import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:go_router/go_router.dart';

/// Builds the tasks routes (protected by the top-level auth redirect).
///
/// `taskDetail` is a child of the list route, so a deep link straight to
/// `/tasks/<id>` still has `/tasks` beneath it to pop back to.
///
/// It also starts [tasksSessionResetProvider]: the router is built at startup,
/// so this is where the tasks slice hooks into the app's lifetime and wipes the
/// previous user's tasks on every session change
/// (koniz-dev/flutter-starter#353).
List<RouteBase> buildTasksRoutes(Ref ref) {
  ref.read(tasksSessionResetProvider);
  return <RouteBase>[
    GoRoute(
      path: AppRoutes.tasks,
      name: AppRoutes.tasksName,
      builder: (context, state) => const TasksListScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: ':${RouteParams.taskId}',
          name: AppRoutes.taskDetailName,
          builder: (context, state) => TaskDetailScreen(
            taskId: state.pathParameters[RouteParams.taskId],
          ),
        ),
      ],
    ),
  ];
}
