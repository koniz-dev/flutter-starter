import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/main.dart' show createAppContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A session kept in memory, so a test can see it cleared.
class InMemorySessionDataSource implements AuthLocalDataSource {
  /// Starts signed in.
  InMemorySessionDataSource.signedIn()
    : user = const UserModel(
        id: 'u-1',
        email: 'signed-in@example.com',
        name: 'Signed In User',
      ),
      token = 'access-token',
      refresh = 'refresh-token';

  /// The cached user, or null once the session is cleared.
  UserModel? user;

  /// The cached access token.
  String? token;

  /// The cached refresh token.
  String? refresh;

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
    user = null;
    token = null;
    refresh = null;
  }
}

/// A server that accepts the logout call and nothing else.
class _LogoutOnlyRemote implements AuthRemoteDataSource {
  @override
  Future<void> logout({String? refreshToken}) async {}

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      throw UnimplementedError();
}

/// The app as `main()` builds it, restored into a signed-in session and
/// settled on home.
typedef SignedInApp = ({
  ProviderContainer container,
  GoRouter router,
  InMemorySessionDataSource session,
});

/// Pumps the whole app - router, redirect and all - signed in.
///
/// [overrides] are added after the session overrides.
Future<SignedInApp> pumpSignedInApp(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final session = InMemorySessionDataSource.signedIn();
  final container = createAppContainer(
    overrides: [
      authLocalDataSourceProvider.overrideWithValue(session),
      authRemoteDataSourceProvider.overrideWithValue(_LogoutOnlyRemote()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await container.read(sessionRestorationProvider.future);
  final router = container.read(goRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
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
  return (container: container, router: router, session: session);
}
