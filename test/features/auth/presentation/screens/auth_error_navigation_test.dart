// An auth error belongs to the screen that raised it
// (koniz-dev/flutter-starter#347).
//
// Both auth screens render the one keepAlive AuthNotifier state, so a failed
// login followed by the "Register" link opened the register form with the
// login error already showing, and the other way round. These drive the real
// router and the real repository; only the remote is replaced, and it rejects
// every sign-in and registration with a 401.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _RejectingRemote implements AuthRemoteDataSource {
  static const _rejected = ServerException('nope', statusCode: 401);

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

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final error = find.text(en.failureInvalidCredentials);

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        ...authModuleOverrides,
        storageServiceProvider.overrideWithValue(InMemoryStorage()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authRemoteDataSourceProvider.overrideWithValue(_RejectingRemote()),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpRouter(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await container.read(sessionRestorationProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(goRouterProvider),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> failLogin(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'a@b.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    await tester.tap(find.byKey(UiKeys.loginSubmit));
    await tester.pumpAndSettle();
  }

  Future<void> failRegister(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'New User');
    await tester.enterText(fields.at(1), 'a@b.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.ensureVisible(find.byKey(UiKeys.registerSubmit));
    await tester.tap(find.byKey(UiKeys.registerSubmit));
    await tester.pumpAndSettle();
  }

  testWidgets('criterion 1: a login error does not follow the user to '
      'RegisterScreen', (tester) async {
    await pumpRouter(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    await failLogin(tester);
    expect(error, findsOneWidget);

    await tester.tap(find.text(en.dontHaveAccount));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(error, findsNothing);
  });

  testWidgets('criterion 2: a register error does not follow the user back '
      'to LoginScreen', (tester) async {
    await pumpRouter(tester);
    await tester.tap(find.text(en.dontHaveAccount));
    await tester.pumpAndSettle();

    await failRegister(tester);
    expect(error, findsOneWidget);

    await tester.ensureVisible(find.text(en.alreadyHaveAccount));
    await tester.tap(find.text(en.alreadyHaveAccount));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(error, findsNothing);
  });

  testWidgets('criterion 3: a fresh submit still raises and replaces the '
      'error', (tester) async {
    await pumpRouter(tester);
    await failLogin(tester);
    await tester.tap(find.text(en.dontHaveAccount));
    await tester.pumpAndSettle();

    await failRegister(tester);
    expect(error, findsOneWidget);
    expect(container.read(authNotifierProvider).failure, isNotNull);

    await failRegister(tester);
    expect(error, findsOneWidget);
  });
}
