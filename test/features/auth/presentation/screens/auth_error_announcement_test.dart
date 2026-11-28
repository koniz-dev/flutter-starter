import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

// A failed sign-in left focus on the submit button and rendered the error as
// plain text, so a screen reader said nothing; while the request ran, the
// button held only a spinner and had no name.

class _HeldAuthRepository extends Mock implements AuthRepository {}

const _rejected = AuthFailure(
  'Invalid credentials',
  code: 'INVALID_CREDENTIALS',
);

Future<void> _pump(WidgetTester tester, Widget screen, AuthRepository repo) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: screen,
      ),
    ),
  );
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  late _HeldAuthRepository repo;
  late Completer<Result<User>> pending;

  setUp(() {
    repo = _HeldAuthRepository();
    when(() => repo.login(any(), any())).thenAnswer((_) => pending.future);
    when(
      () => repo.register(any(), any(), any()),
    ).thenAnswer((_) => pending.future);
  });

  /// Fills [screen]'s form and taps [submit], leaving the request held.
  Future<void> submitHeld(
    WidgetTester tester,
    Widget screen,
    Key submit,
  ) async {
    // Created inside the test's fake-async zone, so completing it is seen by
    // pumpAndSettle.
    pending = Completer<Result<User>>();
    await _pump(tester, screen, repo);
    final fields = find.byType(TextFormField);
    final values = screen is RegisterScreen
        ? ['New User', 'a@b.com', 'password123']
        : ['a@b.com', 'password123'];
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(fields.at(i), values[i]);
    }
    await tester.ensureVisible(find.byKey(submit));
    await tester.tap(find.byKey(submit));
    await tester.pump();
  }

  final screens = <String, (Widget, Key, String Function())>{
    'LoginScreen': (const LoginScreen(), UiKeys.loginSubmit, () => en.login),
    'RegisterScreen': (
      const RegisterScreen(),
      UiKeys.registerSubmit,
      () => en.register,
    ),
  };

  for (final MapEntry(key: name, value: (screen, submit, label))
      in screens.entries) {
    testWidgets('$name: the loading button keeps its label', (tester) async {
      final handle = tester.ensureSemantics();
      await submitHeld(tester, screen, submit);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(submit)),
        isSemantics(label: label(), isButton: true),
      );

      pending.complete(const ResultFailure<User>(_rejected));
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('$name: a failure is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await submitHeld(tester, screen, submit);
      pending.complete(const ResultFailure<User>(_rejected));
      await tester.pumpAndSettle();

      final message = _rejected.localizedMessage(en);
      expect(find.text(message), findsOneWidget);
      expect(
        tester.getSemantics(find.text(message)),
        isSemantics(label: message, isLiveRegion: true),
      );
      handle.dispose();
    });
  }
}
