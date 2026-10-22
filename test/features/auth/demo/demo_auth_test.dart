// The offline demo sign-in: when it is on, what it accepts, and that a fresh
// app can go from the login screen to home with no backend.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/demo/demo_auth.dart';
import 'package:flutter_starter/features/auth/demo/demo_sign_in_card.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/main.dart' show createAppContainer;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

void main() {
  group('criterion 2: demo mode is on only in an unconfigured debug build', () {
    test('no BASE_URL, development, debug build: on', () {
      expect(
        DemoAuth.isEnabledFor(
          debugBuild: true,
          environment: 'development',
          baseUrl: '',
        ),
        isTrue,
      );
    });

    test('a configured BASE_URL turns it off', () {
      expect(
        DemoAuth.isEnabledFor(
          debugBuild: true,
          environment: 'development',
          baseUrl: 'https://api.example.com',
        ),
        isFalse,
      );
    });

    test('a profile or release build can never enable it', () {
      expect(
        DemoAuth.isEnabledFor(
          debugBuild: false,
          environment: 'development',
          baseUrl: '',
        ),
        isFalse,
      );
    });

    for (final environment in ['staging', 'production']) {
      test('the $environment environment turns it off', () {
        expect(
          DemoAuth.isEnabledFor(
            debugBuild: true,
            environment: environment,
            baseUrl: '',
          ),
          isFalse,
        );
      });
    }

    test('whitespace is not a BASE_URL', () {
      expect(
        DemoAuth.isEnabledFor(
          debugBuild: true,
          environment: 'development',
          baseUrl: '  ',
        ),
        isTrue,
      );
    });
  });

  group('the demo data source', () {
    test('the demo account signs in and gets tokens', () async {
      final response = await DemoAuthRemoteDataSource().login(
        DemoAuth.email,
        DemoAuth.password,
      );
      expect(response.user.email, DemoAuth.email);
      expect(response.token, isNotEmpty);
      expect(response.refreshToken, isNotEmpty);
    });

    test('a wrong password is an AuthException, like a 401', () {
      expect(
        () => DemoAuthRemoteDataSource().login(DemoAuth.email, 'wrong-pass'),
        throwsA(isA<AuthException>()),
      );
    });

    test('a registered account can sign in again', () async {
      final source = DemoAuthRemoteDataSource();
      await source.register('new@example.com', 'secret123', 'New');
      final response = await source.login('new@example.com', 'secret123');
      expect(response.user.name, 'New');
    });

    test('a refresh token works once, then is spent', () async {
      final source = DemoAuthRemoteDataSource();
      final first = await source.login(DemoAuth.email, DemoAuth.password);
      final refreshed = await source.refreshToken(first.refreshToken!);
      expect(refreshed.token, isNot(first.token));
      expect(
        () => source.refreshToken(first.refreshToken!),
        throwsA(isA<AuthException>()),
      );
    });

    test('the provider picks it only while demo mode is on', () {
      addTearDown(() => DemoAuth.debugEnabledOverride = false);
      DemoAuth.debugEnabledOverride = true;
      final on = ProviderContainer();
      addTearDown(on.dispose);
      expect(
        on.read(authRemoteDataSourceProvider),
        isA<DemoAuthRemoteDataSource>(),
      );

      DemoAuth.debugEnabledOverride = false;
      final off = ProviderContainer();
      addTearDown(off.dispose);
      expect(
        off.read(authRemoteDataSourceProvider),
        isNot(isA<DemoAuthRemoteDataSource>()),
      );
    });
  });

  group(
    'criterion 3: removing it is one folder and the files that import it',
    () {
      test('only the provider and the login screen import the demo', () {
        final importers =
            Directory('lib')
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))
                .where((f) => !f.path.contains('/features/auth/demo/'))
                .where(
                  (f) => f.readAsStringSync().contains('/features/auth/demo/'),
                )
                .map((f) => f.path)
                .toList()
              ..sort();
        // The removal recipe in docs/guides/onboarding/getting-started.md
        // ("Signing In Before You Have a Backend") names these files. Adding an
        // importer means updating that recipe and this list together.
        expect(importers, [
          'lib/features/auth/di/auth_providers.dart',
          'lib/features/auth/presentation/screens/login_screen.dart',
        ]);
      });
    },
  );

  group('criterion 3: login -> demo sign-in -> home, with no backend', () {
    setUp(() => DemoAuth.debugEnabledOverride = true);
    tearDown(() => DemoAuth.debugEnabledOverride = false);

    testWidgets('the fill button and Login reach the home screen', (
      tester,
    ) async {
      final container = createAppContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            AuthLocalDataSourceImpl(
              storageService: InMemoryKeyValueStore(),
              tokenStore: InMemoryTokenStore(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
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
            supportedLocales: LocalizationService.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DemoSignInCard), findsOneWidget);
      // Criterion 2: the demo path is labelled as demo, with its credentials.
      expect(find.text('Demo mode'), findsOneWidget);
      expect(find.textContaining('BASE_URL is empty'), findsOneWidget);
      expect(find.textContaining(DemoAuth.email), findsOneWidget);
      expect(find.text('Fill in the demo account'), findsOneWidget);

      await tester.tap(find.byKey(UiKeys.demoSignInFill));
      await tester.pump();
      await tester.tap(find.byKey(UiKeys.loginSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(UiKeys.homeContent), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('with demo mode off the login screen shows no demo card', (
      tester,
    ) async {
      DemoAuth.debugEnabledOverride = false;
      final container = createAppContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DemoSignInCard), findsNothing);
    });
  });
}
