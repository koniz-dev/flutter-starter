import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

// koniz-dev/flutter-starter#348: the guard parks a deep link as
// `/login?redirect=<path>`, but the register link went to a bare `/register`,
// so a new user who opened a shared link landed on `/` after signing up.

class _MockRegisterUseCase extends Mock implements RegisterUseCase {}

const _newUser = User(id: 'new', email: 'new@example.com', name: 'New');

void main() {
  late _MockRegisterUseCase registerUseCase;

  setUp(() {
    registerUseCase = _MockRegisterUseCase();
    when(
      () => registerUseCase(any(), any(), any()),
    ).thenAnswer((_) async => const Success<User>(_newUser));
  });

  Future<GoRouter> pumpRouter(WidgetTester tester) => pumpAppRouter(
    tester,
    overrides: [
      sessionRestorationProvider.overrideWith((ref) async {}),
      registerUseCaseProvider.overrideWithValue(registerUseCase),
    ],
  );

  Uri location(GoRouter router) => router.routeInformationProvider.value.uri;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> register(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RegisterScreen)),
    );
    await container
        .read(authNotifierProvider.notifier)
        .register('new@example.com', 'password123', 'New');
    // Not pumpAndSettle: the deep link's own screen may keep a spinner going
    // (and this file must not import the tasks feature to stub it - the strip
    // removes that slice). Only the router's location is asserted.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('criteria 1-2: the register link keeps redirect, and signing '
      'up lands on the deep link', (tester) async {
    final router = await pumpRouter(tester);
    router.go('/tasks/42');
    await tester.pumpAndSettle();
    expect(location(router).toString(), '/login?redirect=%2Ftasks%2F42');

    await tapText(tester, "Don't have an account? Register");

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(location(router).toString(), '/register?redirect=%2Ftasks%2F42');

    await register(tester);

    expect(location(router).toString(), '/tasks/42');
  });

  testWidgets('criterion 3: "Already have an account?" keeps redirect too', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    // Arrive on /register directly (no back stack), as a shared register
    // link would.
    router.go('${AppRoutes.register}?redirect=%2Ftasks%2F42');
    await tester.pumpAndSettle();

    await tapText(tester, 'Already have an account? Login');

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(location(router).toString(), '/login?redirect=%2Ftasks%2F42');
  });

  testWidgets('criterion 4: an off-site redirect through register lands on /', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    router.go('${AppRoutes.login}?redirect=https://evil.example.com/steal');
    await tester.pumpAndSettle();

    await tapText(tester, "Don't have an account? Register");
    expect(location(router).path, AppRoutes.register);

    await register(tester);

    expect(location(router).path, AppRoutes.home);
    expect(location(router).host, isEmpty);
  });
}
