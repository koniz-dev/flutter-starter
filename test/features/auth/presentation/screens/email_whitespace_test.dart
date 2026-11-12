import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _Login extends Mock implements LoginUseCase {}

class _Register extends Mock implements RegisterUseCase {}

void main() {
  const email = 'a@example.com';
  const password = 'Password123! ';

  testWidgets('login accepts a trailing-space email and submits it trimmed', (
    tester,
  ) async {
    final useCase = _Login();
    when(() => useCase(any(), any())).thenAnswer(
      (_) async => const ResultFailure(ServerFailure('synthetic rejection')),
    );
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: [loginUseCaseProvider.overrideWithValue(useCase)],
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '$email ');
    await tester.enterText(fields.at(1), password);
    await tester.ensureVisible(find.byKey(UiKeys.loginSubmit));
    await tester.tap(find.byKey(UiKeys.loginSubmit));
    await tester.pumpAndSettle();

    verify(() => useCase(email, password)).called(1);
  });

  testWidgets(
    'registration accepts a trailing-space email and submits it trimmed',
    (
      tester,
    ) async {
      final useCase = _Register();
      when(() => useCase(any(), any(), any())).thenAnswer(
        (_) async => const ResultFailure(ServerFailure('synthetic rejection')),
      );
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: [registerUseCaseProvider.overrideWithValue(useCase)],
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'New User');
      await tester.enterText(fields.at(1), '$email ');
      await tester.enterText(fields.at(2), password);
      await tester.ensureVisible(find.byKey(UiKeys.registerSubmit));
      await tester.tap(find.byKey(UiKeys.registerSubmit));
      await tester.pumpAndSettle();

      verify(() => useCase(email, password, 'New User')).called(1);
    },
  );
}
