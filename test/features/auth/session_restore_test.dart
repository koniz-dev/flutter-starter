import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// Regression tests for #51: the persisted session was never read back, so
/// every cold start redirected a returning user to `/login`.
///
/// These drive the real chain - local datasource -> repository -> use case ->
/// [AuthNotifier] -> [goRouterProvider] redirect - and assert the router's
/// location, which is the observable the bug was about.

class _StubLocalDataSource implements AuthLocalDataSource {
  _StubLocalDataSource({
    this.user,
    this.token,
    this.onGetCachedUser,
    this.onGetToken,
  });

  final UserModel? user;
  final String? token;

  /// Invoked before [getCachedUser] answers, so a test can make storage fail.
  final void Function()? onGetCachedUser;

  /// Invoked before [getToken] answers, for the same reason.
  final void Function()? onGetToken;

  @override
  Future<UserModel?> getCachedUser() async {
    onGetCachedUser?.call();
    return user;
  }

  @override
  Future<String?> getToken() async {
    onGetToken?.call();
    return token;
  }

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

class _MockKeyValueStore extends Mock implements IKeyValueStore {}

class _MockTokenStore extends Mock implements ITokenStore {}

class _MockLoginUseCase extends Mock implements LoginUseCase {}

const _cachedUser = UserModel(
  id: 'u-1',
  email: 'returning@example.com',
  name: 'Returning User',
);

/// Pumps the real app router inside a minimal MaterialApp.router host.
///
/// Deliberately not `test/helpers/pump_app.dart`: that helper builds its own
/// `MaterialApp` with a `home:` widget and therefore has no router, and the
/// router is exactly what is under test here.
Future<GoRouter> _pumpRouter(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 3000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
        supportedLocales: const [Locale('en')],
      ),
    ),
  );

  return router;
}

Uri _location(GoRouter router) => router.routeInformationProvider.value.uri;

void main() {
  group('cold start session restore (#51)', () {
    late ProviderContainer container;

    tearDown(() => container.dispose());

    testWidgets('a cached session lands on / instead of /login', (
      tester,
    ) async {
      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(user: _cachedUser, token: 'valid-token'),
          ),
        ],
      );

      // What main() does before runApp.
      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(container.read(authNotifierProvider).user, _cachedUser);
    });

    testWidgets('empty storage still lands on /login', (tester) async {
      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(),
          ),
        ],
      );

      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(authNotifierProvider).user, isNull);
    });

    testWidgets('restore in flight does not flash /login, then lands on /', (
      tester,
    ) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });

      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(user: _cachedUser, token: 'valid-token'),
          ),
          // Same restore, held open so the in-flight window is observable.
          sessionRestorationProvider.overrideWith((ref) async {
            await gate.future;
            await ref.read(authNotifierProvider.notifier).restoreSession();
          }),
        ],
      );

      final router = await _pumpRouter(tester, container);
      await tester.pump();

      // The intermediate state itself, not just the outcome: restore has not
      // answered, the user is not yet authenticated, and the guard must NOT
      // treat that as "logged out".
      expect(container.read(sessionRestorationProvider).isLoading, isTrue);
      expect(container.read(authNotifierProvider).user, isNull);
      expect(_location(router).path, isNot(AppRoutes.login));
      expect(_location(router).path, AppRoutes.home);
      expect(find.byType(LoginScreen), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(container.read(sessionRestorationProvider).isLoading, isFalse);
      expect(_location(router).path, AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('restore held open for a user with no session ends on /login', (
      tester,
    ) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });

      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(),
          ),
          sessionRestorationProvider.overrideWith((ref) async {
            await gate.future;
            await ref.read(authNotifierProvider.notifier).restoreSession();
          }),
        ],
      );

      final router = await _pumpRouter(tester, container);
      await tester.pump();
      expect(_location(router).path, AppRoutes.home);

      gate.complete();
      await tester.pumpAndSettle();

      // A restore that finds nothing leaves the auth state untouched, so the
      // guard has to be re-run by the restore listener, not the auth one.
      expect(_location(router).path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('corrupt cached JSON lands on /login without throwing', (
      tester,
    ) async {
      final store = _MockKeyValueStore();
      when(
        () => store.getString(AppConstants.userDataKey),
      ).thenAnswer((_) async => '{ this is not json');
      // The token is read first (#85), so it has to be readable for the
      // corrupt blob below to be reached at all.
      final tokenStore = _MockTokenStore();
      when(tokenStore.getAccessToken).thenAnswer((_) async => 'valid-token');

      container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          tokenStoreProvider.overrideWithValue(tokenStore),
        ],
      );

      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('storage throwing lands on /login without throwing', (
      tester,
    ) async {
      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(
              // An Error, not an Exception: the data layer only converts
              // Exceptions, so this is what escapes if nothing catches it.
              onGetCachedUser: () => throw StateError('storage is gone'),
            ),
          ),
        ],
      );

      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  /// Regression tests for #85: the cold-start restore promoted a device to
  /// authenticated on the cached user blob alone, never consulting the token
  /// store, so a device holding a stale blob with no credentials booted into
  /// the authenticated shell and then 401'd on every request.
  ///
  /// These sit beside the #51 cases deliberately: the two issues pull in
  /// opposite directions (restore more eagerly / restore less eagerly) and the
  /// only way to see that neither has been over-corrected is to read them
  /// together.
  group('cold start requires a token, not just a cached user (#85)', () {
    late ProviderContainer container;

    tearDown(() => container.dispose());

    testWidgets('a cached user with no token lands on /login, not /', (
      tester,
    ) async {
      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            // The exact state AuthInterceptor's forced logout leaves if the
            // user blob outlives the token clear.
            _StubLocalDataSource(user: _cachedUser),
          ),
        ],
      );

      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(container.read(authNotifierProvider).user, isNull);
    });

    testWidgets('a cached user with an empty token lands on /login', (
      tester,
    ) async {
      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(user: _cachedUser, token: ''),
          ),
        ],
      );

      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(authNotifierProvider).user, isNull);
    });

    testWidgets('an unreadable token store lands on /login without throwing', (
      tester,
    ) async {
      // The real data source over a failing token store, so the failure is
      // wrapped exactly as it would be on device (CacheException), rather than
      // simulated at the repository boundary.
      final store = _MockKeyValueStore();
      when(
        () => store.getString(AppConstants.userDataKey),
      ).thenAnswer((_) async => jsonEncode(_cachedUser.toJson()));

      final tokenStore = _MockTokenStore();
      when(
        tokenStore.getAccessToken,
      ).thenThrow(Exception('keychain is unreadable'));

      container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          tokenStoreProvider.overrideWithValue(tokenStore),
        ],
      );

      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(authNotifierProvider).user, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a token store throwing an Error lands on /login without throwing',
      (tester) async {
        container = ProviderContainer(
          overrides: [
            authLocalDataSourceProvider.overrideWithValue(
              _StubLocalDataSource(
                user: _cachedUser,
                // An Error, not an Exception: the data layer only converts
                // Exceptions, so this is what escapes if nothing catches it.
                onGetToken: () => throw StateError('secure storage is gone'),
              ),
            ),
          ],
        );

        await container.read(sessionRestorationProvider.future);

        final router = await _pumpRouter(tester, container);
        await tester.pumpAndSettle();

        expect(_location(router).path, AppRoutes.login);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a cached user with a readable token still lands on /', (
      tester,
    ) async {
      // The other direction: #85 must not undo #51. An expired-but-present
      // token is indistinguishable from a fresh one here by design (see
      // AuthNotifier.restoreSession), so "present" is the whole test.
      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(user: _cachedUser, token: 'expired-token'),
          ),
        ],
      );

      await container.read(sessionRestorationProvider.future);

      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(container.read(authNotifierProvider).user, _cachedUser);
    });
  });

  group('deep link survives the login round trip (#51)', () {
    late ProviderContainer container;

    tearDown(() => container.dispose());

    testWidgets('bounce to /login carries the destination, and returns to it', (
      tester,
    ) async {
      const deepLink = '/?from=deep-link';
      final loginUseCase = _MockLoginUseCase();
      when(
        () => loginUseCase(any(), any()),
      ).thenAnswer((_) async => const Success<User>(_cachedUser));

      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(),
          ),
          loginUseCaseProvider.overrideWithValue(loginUseCase),
        ],
      );

      await container.read(sessionRestorationProvider.future);
      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      router.go(deepLink);
      await tester.pumpAndSettle();

      // Bounced to login, but the destination is remembered.
      expect(_location(router).path, AppRoutes.login);
      expect(
        _location(router).queryParameters[RouteQueryParams.redirect],
        deepLink,
      );

      await container
          .read(authNotifierProvider.notifier)
          .login('returning@example.com', 'password123');
      await tester.pumpAndSettle();

      expect(_location(router).toString(), deepLink);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('an off-site redirect target is ignored', (tester) async {
      final loginUseCase = _MockLoginUseCase();
      when(
        () => loginUseCase(any(), any()),
      ).thenAnswer((_) async => const Success<User>(_cachedUser));

      container = ProviderContainer(
        overrides: [
          authLocalDataSourceProvider.overrideWithValue(
            _StubLocalDataSource(),
          ),
          loginUseCaseProvider.overrideWithValue(loginUseCase),
        ],
      );

      await container.read(sessionRestorationProvider.future);
      final router = await _pumpRouter(tester, container);
      await tester.pumpAndSettle();

      router.go('${AppRoutes.login}?redirect=https://evil.example.com/steal');
      await tester.pumpAndSettle();

      await container
          .read(authNotifierProvider.notifier)
          .login('returning@example.com', 'password123');
      await tester.pumpAndSettle();

      expect(_location(router).path, AppRoutes.home);
      expect(_location(router).host, isEmpty);
    });
  });
}
