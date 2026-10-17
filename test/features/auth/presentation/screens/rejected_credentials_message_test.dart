// A rejected login says the credentials are wrong, not that the session
// ended (koniz-dev/flutter-starter#445).
//
// Since #309 a 401 on login is an AuthFailure, and every AuthFailure rendered
// failureAuth - "you're not signed in, or your session has ended". The
// repository now tags a sign-in AuthFailure with
// FailureCodes.invalidCredentials (#479). These tests drive the real
// AuthRepositoryImpl and AuthNotifier; only the remote data source is
// replaced, and it rejects the credentials the way the network layer does: a
// ServerException carrying 401.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

/// A backend that rejects every sign-in and registration with 401.
class _RejectingRemote implements AuthRemoteDataSource {
  static const _rejected = ServerException(
    'Invalid email or password',
    statusCode: 401,
  );

  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      throw _rejected;

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async => throw _rejected;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      throw _rejected;
}

Future<void> _pump(WidgetTester tester, Widget screen, Locale locale) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(InMemoryStorage()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authRemoteDataSourceProvider.overrideWithValue(_RejectingRemote()),
      ],
      child: MaterialApp(
        locale: locale,
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
  for (final locale in const [Locale('en'), Locale('vi')]) {
    final l10n = lookupAppLocalizations(locale);

    testWidgets('criterion 2 (${locale.languageCode}): a rejected login '
        'renders failureInvalidCredentials, not failureAuth', (tester) async {
      await _pump(tester, const LoginScreen(), locale);

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong-pass');
      await tester.tap(find.byKey(UiKeys.loginSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.failureInvalidCredentials), findsOneWidget);
      expect(find.text(l10n.failureAuth), findsNothing);
    });

    testWidgets('criterion 2 (${locale.languageCode}): a rejected '
        'registration renders it too', (tester) async {
      await _pump(tester, const RegisterScreen(), locale);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'New User');
      await tester.enterText(fields.at(1), 'a@b.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.ensureVisible(find.byKey(UiKeys.registerSubmit));
      await tester.tap(find.byKey(UiKeys.registerSubmit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.failureInvalidCredentials), findsOneWidget);
      expect(find.text(l10n.failureAuth), findsNothing);
    });

    test('criterion 3 (${locale.languageCode}): an expired-session '
        'AuthFailure still renders failureAuth', () {
      const expired = AuthFailure(
        'Refresh token expired',
        code: AuthErrorCodes.refreshTokenExpired,
      );
      expect(expired.localizedMessage(l10n), l10n.failureAuth);
    });
  }

  test('criterion 3: the refresh path tags its 401 as an expired session, '
      'not as invalid credentials', () async {
    final container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(InMemoryStorage()),
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore()..refreshToken = 'old-refresh',
        ),
        authRemoteDataSourceProvider.overrideWithValue(_RejectingRemote()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(authRepositoryProvider).refreshToken();

    expect(
      result.failureOrNull,
      isA<AuthFailure>().having(
        (f) => f.code,
        'code',
        AuthErrorCodes.refreshTokenExpired,
      ),
    );
  });
}
