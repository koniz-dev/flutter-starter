// The tasks list formats dates in the device's region.
//
// With an en_GB device the app reported en_US (the region hard-coded in
// SupportedLocale, and the one MaterialApp's default resolution picked), so
// the list read 9 March 2026 as 3/9/2026.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/tasks/di/tasks_providers.dart';
import 'package:flutter_starter/features/tasks/domain/entities/task.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/get_all_tasks_usecase.dart';
import 'package:flutter_starter/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:flutter_starter/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(id: '1', email: 'test@example.com'),
  );
}

class _MockGetAllTasksUseCase extends Mock implements GetAllTasksUseCase {}

final DateTime _ninthOfMarch = DateTime(2026, 3, 9);

/// Boots the real [MyApp] on [device] with [stored] preferences, signed in,
/// and opens the tasks list holding one task created on 9 March 2026.
Future<ProviderContainer> _pumpTasksList(
  WidgetTester tester, {
  required List<Locale> device,
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  tester.platformDispatcher.localesTestValue = device;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final getAllTasks = _MockGetAllTasksUseCase();
  when(getAllTasks.call).thenAnswer(
    (_) async => Success<List<Task>>([
      Task(
        id: 'a',
        title: 'Alpha',
        createdAt: _ninthOfMarch,
        updatedAt: _ninthOfMarch,
      ),
    ]),
  );
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_SignedIn.new),
      sessionRestorationProvider.overrideWith((ref) async {}),
      getAllTasksUseCaseProvider.overrideWithValue(getAllTasks),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  container.read(goRouterProvider).go(AppRoutes.tasks);
  await tester.pumpAndSettle(const Duration(seconds: 5));
  expect(find.byType(TasksListScreen), findsOneWidget);
  return container;
}

Locale _screenLocale(WidgetTester tester) =>
    Localizations.localeOf(tester.element(find.byType(TasksListScreen)));

void main() {
  testWidgets('no stored choice: an en_GB device reports en_GB and a British '
      'date', (tester) async {
    await _pumpTasksList(tester, device: const [Locale('en', 'GB')]);

    expect(_screenLocale(tester), const Locale('en', 'GB'));
    expect(find.text('09/03/2026'), findsOneWidget);
    expect(find.text('3/9/2026'), findsNothing);
  });

  testWidgets('stored en on an en_GB device stays en_GB', (tester) async {
    await _pumpTasksList(
      tester,
      device: const [Locale('en', 'GB')],
      stored: const {'language': 'en'},
    );

    expect(_screenLocale(tester), const Locale('en', 'GB'));
    expect(find.text('09/03/2026'), findsOneWidget);
  });
}
