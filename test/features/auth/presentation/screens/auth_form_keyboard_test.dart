// The auth forms ignored the keyboard's action key (Done did not submit,
// Next did not move on), gave password managers no autofill hints, and had
// no way to reveal a typed password.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockRegisterUseCase extends Mock implements RegisterUseCase {}

final _l10n = AppLocalizationsEn();
const _user = User(id: '1', email: 'a@b.co');

void main() {
  late _MockLoginUseCase login;
  late _MockRegisterUseCase register;

  setUp(() {
    login = _MockLoginUseCase();
    register = _MockRegisterUseCase();
    when(() => login(any(), any()))
        .thenAnswer((_) async => const Success(_user));
    when(
      () => register(any(), any(), any()),
    ).thenAnswer((_) async => const Success(_user));
  });

  Future<void> pump(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const RegisterScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginUseCaseProvider.overrideWithValue(login),
          registerUseCaseProvider.overrideWithValue(register),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: LocalizationService.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextField field(WidgetTester tester, String label) =>
      tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(TextField),
        ),
      );

  group('login', () {
    testWidgets('Done on the password field signs in', (tester) async {
      await pump(tester, AppRoutes.login);
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.email),
        'a@b.co',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.password),
        'password123',
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(() => login('a@b.co', 'password123')).called(1);
    });

    testWidgets('fields carry keyboard actions and autofill hints', (
      tester,
    ) async {
      await pump(tester, AppRoutes.login);

      final email = field(tester, _l10n.email);
      final password = field(tester, _l10n.password);
      expect(email.textInputAction, TextInputAction.next);
      expect(email.autofillHints, [AutofillHints.email]);
      expect(password.textInputAction, TextInputAction.done);
      expect(password.autofillHints, [AutofillHints.password]);
      expect(find.byType(AutofillGroup), findsOneWidget);
    });

    testWidgets('the password can be shown and hidden again', (tester) async {
      await pump(tester, AppRoutes.login);
      expect(field(tester, _l10n.password).obscureText, isTrue);

      await tester.tap(find.byTooltip(_l10n.showPassword));
      await tester.pump();
      expect(field(tester, _l10n.password).obscureText, isFalse);

      await tester.tap(find.byTooltip(_l10n.hidePassword));
      await tester.pump();
      expect(field(tester, _l10n.password).obscureText, isTrue);
    });
  });

  group('register', () {
    testWidgets('Done on the password field registers', (tester) async {
      await pump(tester, AppRoutes.register);
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.name),
        'Ann',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.email),
        'a@b.co',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.password),
        'password123',
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(() => register('a@b.co', 'password123', 'Ann')).called(1);
    });

    testWidgets('fields carry keyboard actions and autofill hints', (
      tester,
    ) async {
      await pump(tester, AppRoutes.register);

      expect(field(tester, _l10n.name).autofillHints, [AutofillHints.name]);
      expect(field(tester, _l10n.name).textInputAction, TextInputAction.next);
      expect(field(tester, _l10n.email).autofillHints, [AutofillHints.email]);
      expect(
        field(tester, _l10n.password).autofillHints,
        [AutofillHints.newPassword],
      );
      expect(find.byType(AutofillGroup), findsOneWidget);
    });

    testWidgets('a whitespace-only name is required, not too short', (
      tester,
    ) async {
      await pump(tester, AppRoutes.register);
      await tester.enterText(
        find.widgetWithText(TextFormField, _l10n.name),
        '   ',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, _l10n.register));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.nameRequired), findsOneWidget);
      expect(find.text(_l10n.nameMinLength(2)), findsNothing);
    });
  });
}
