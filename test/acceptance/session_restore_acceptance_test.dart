@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'acceptance_helpers.dart';

/// Visual evidence for #51: what a cold start actually shows, with and
/// without a persisted session.
///
/// Remember what these PNGs can and cannot prove (see acceptance_helpers.dart):
/// every glyph is an opaque Ahem block, so the screen *identity* is asserted
/// with finders below and the golden only shows which screen was laid out.

class _StubLocalDataSource implements AuthLocalDataSource {
  _StubLocalDataSource({this.user, this.token});

  final UserModel? user;
  final String? token;

  @override
  Future<UserModel?> getCachedUser() async => user;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> cacheUser(UserModel user) async {}

  @override
  Future<void> cacheToken(String token) async {}

  @override
  Future<void> cacheRefreshToken(String token) async {}

  @override
  Future<void> clearCache() async {}
}

/// Boots the real router the way `main()` does: restore first, then frame.
Future<GoRouter> _pumpColdStart(
  WidgetTester tester, {
  required AuthLocalDataSource localDataSource,
}) async {
  await tester.binding.setSurfaceSize(kAcceptanceSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [
      authLocalDataSourceProvider.overrideWithValue(localDataSource),
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

  return router;
}

void main() {
  group('cold start acceptance (#51)', () {
    testWidgets('with a persisted session the app opens on home', (
      tester,
    ) async {
      final router = await _pumpColdStart(
        tester,
        localDataSource: _StubLocalDataSource(
          user: const UserModel(
            id: 'u-1',
            email: 'returning@example.com',
            name: 'Returning User',
          ),
          token: 'valid-token',
        ),
      );

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await captureAcceptanceGolden(
        find.byType(MaterialApp),
        'cold_start_restored_session',
      );
    });

    testWidgets('with empty storage the app opens on login', (tester) async {
      final router = await _pumpColdStart(
        tester,
        localDataSource: _StubLocalDataSource(),
      );

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await captureAcceptanceGolden(
        find.byType(MaterialApp),
        'cold_start_no_session',
      );
    });
  });
}
