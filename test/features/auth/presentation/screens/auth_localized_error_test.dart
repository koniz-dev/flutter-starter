import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// koniz-dev/flutter-starter#414: AuthNotifier stored `failure.message` - the
// English text DioExceptionMapper builds for logs, sometimes with dio's own
// wording appended - and both auth screens rendered it verbatim, so a
// Vietnamese user saw "Connection error: ..." instead of their language.

class _OfflineAuthRepository extends Mock implements AuthRepository {}

/// What `DioExceptionMapper` produces for a dropped connection.
const _offline = NetworkFailure(
  'Connection error: The connection errored: Failed host lookup. This '
  'indicates an error which most likely cannot be solved by the library.',
  code: 'CONNECTION_ERROR',
);

const _vi = Locale('vi');

Future<void> _pump(WidgetTester tester, Widget screen, AuthRepository repo) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: _vi,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: screen,
      ),
    ),
  );
}

void main() {
  late _OfflineAuthRepository repo;
  final vi = lookupAppLocalizations(_vi);

  setUp(() {
    repo = _OfflineAuthRepository();
    when(
      () => repo.login(any(), any()),
    ).thenAnswer((_) async => const ResultFailure<User>(_offline));
    when(
      () => repo.register(any(), any(), any()),
    ).thenAnswer((_) async => const ResultFailure<User>(_offline));
  });

  void expectLocalizedOnly(WidgetTester tester) {
    expect(find.text(vi.failureNoConnection), findsOneWidget);
    expect(find.textContaining('Connection error'), findsNothing);
    expect(find.textContaining('cannot be solved'), findsNothing);
  }

  testWidgets('criterion 2: LoginScreen in vi renders the localized '
      'CONNECTION_ERROR message, not the transport text', (tester) async {
    await _pump(tester, const LoginScreen(), repo);

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.byKey(UiKeys.loginSubmit));
    await tester.pumpAndSettle();

    verify(() => repo.login('a@b.com', 'password123')).called(1);
    expectLocalizedOnly(tester);
  });

  testWidgets('RegisterScreen in vi renders it the same way', (tester) async {
    await _pump(tester, const RegisterScreen(), repo);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'New User');
    await tester.enterText(fields.at(1), 'a@b.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.ensureVisible(find.byKey(UiKeys.registerSubmit));
    await tester.tap(find.byKey(UiKeys.registerSubmit));
    await tester.pumpAndSettle();

    verify(() => repo.register(any(), any(), any())).called(1);
    expectLocalizedOnly(tester);
  });
}
