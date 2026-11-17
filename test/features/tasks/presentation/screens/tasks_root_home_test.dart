import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// A deep link or a `?redirect=/tasks` sign-in landed on the tasks list as the
// only page: no back button, and no way to Home or to Sign out from there.
// This drives the app's own router, so `go` leaves nothing beneath the list
// and `pushRoute` (how Home opens it) leaves Home beneath it.

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(id: '1', email: 'test@example.com'),
  );
}

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

final String _home = AppLocalizationsEn().backToHome;

Future<GoRouter> _pump(WidgetTester tester) {
  final getAllTasks = _MockGetAllTasksUseCase();
  when(getAllTasks.call).thenAnswer((_) async => const Success(<Task>[]));
  return pumpAppRouter(
    tester,
    overrides: [
      authNotifierProvider.overrideWith(_TestAuthNotifier.new),
      sessionRestorationProvider.overrideWith((ref) async {}),
      getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
    ],
  );
}

void main() {
  testWidgets('the list reached with nothing beneath it offers Home', (
    tester,
  ) async {
    final router = await _pump(tester);
    router.go(AppRoutes.tasks);
    await tester.pumpAndSettle();
    expect(find.byType(TasksListScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byTooltip(_home));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.home);
    expect(find.byType(TasksListScreen), findsNothing);
  });

  testWidgets('the list opened from Home keeps its back button', (
    tester,
  ) async {
    final router = await _pump(tester);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    tester.element(find.byType(Scaffold).last).pushRoute(AppRoutes.tasks);
    await tester.pumpAndSettle();

    expect(find.byType(TasksListScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byTooltip(_home), findsNothing);
  });
}
