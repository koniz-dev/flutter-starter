@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'acceptance_helpers.dart';

/// Visual evidence for #52: what the app shows after a logout whose remote
/// call failed. Before the fix the local session survived and the app stayed
/// on home; it now lands on login with the failure surfaced.
///
/// Remember what these PNGs can and cannot prove (see acceptance_helpers.dart):
/// every glyph is an opaque Ahem block, so the screen *identity* is asserted
/// with finders below and the golden only shows which screen was laid out.

/// Session held in memory, so `clearCache()` is observable in the PNG: it is
/// what decides whether the app can still present a signed-in session.
class _InMemorySessionDataSource implements AuthLocalDataSource {
  UserModel? user;
  String? token;
  String? refresh;
  int clearCacheCalls = 0;

  @override
  Future<UserModel?> getCachedUser() async => user;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<String?> getRefreshToken() async => refresh;

  @override
  Future<void> cacheUser(UserModel user) async => this.user = user;

  @override
  Future<void> cacheToken(String token) async => this.token = token;

  @override
  Future<void> cacheRefreshToken(String token) async => refresh = token;

  @override
  Future<void> clearCache() async {
    clearCacheCalls++;
    user = null;
    token = null;
    refresh = null;
  }
}

/// Remote source whose `logout()` always fails - an offline device, a 500, or
/// an adopter who has not implemented `/auth/logout` yet.
class _FailingRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<void> logout() async =>
      throw const NetworkException('No internet connection');

  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async => throw UnimplementedError();

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      throw UnimplementedError();
}

void main() {
  group('failed logout acceptance (#52)', () {
    testWidgets('a logout whose remote call fails still lands on login', (
      tester,
    ) async {
      // `authRepositoryProvider` resolves the real `ApiClient`, whose response
      // cache is backed by SharedPreferences; without the mock the logout
      // teardown awaits a platform channel nothing answers.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(kAcceptanceSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = _InMemorySessionDataSource()
        ..user = const UserModel(
          id: 'u-1',
          email: 'signed-in@example.com',
          name: 'Signed In User',
        )
        ..token = 'access-token'
        ..refresh = 'refresh-token';

      final container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(localDataSource),
          authRemoteDataSourceProvider.overrideWithValue(
            _FailingRemoteDataSource(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionRestorationProvider.future);
      final router = container.read(goRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
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

      // Signed in: the app is on home.
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      await captureAcceptanceGolden(
        find.byType(MaterialApp),
        'failed_logout_before_home',
      );

      await container.read(authNotifierProvider.notifier).logout();
      await tester.pumpAndSettle();

      // The remote call failed, yet the session is gone and the app is on
      // login rather than still showing an authenticated screen.
      expect(localDataSource.clearCacheCalls, 1);
      expect(localDataSource.token, isNull);
      expect(localDataSource.refresh, isNull);
      expect(localDataSource.user, isNull);
      expect(container.read(authNotifierProvider).user, isNull);
      expect(
        container.read(authNotifierProvider).error,
        'No internet connection',
      );
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await captureAcceptanceGolden(
        find.byType(MaterialApp),
        'failed_logout_after_login',
      );
    });
  });
}
