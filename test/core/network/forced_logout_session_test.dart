// A forced logout must end the session in the app that is *running*, not only
// on the device.
//
// Regression cover for koniz-dev/flutter-starter#127. `AuthInterceptor`
// cleared the tokens (#59), the cached user blob (#85's precondition) and the
// HTTP response cache (#114) - the whole persisted session - and told nobody.
// `AuthNotifier` still held a `User` in memory, the router guard reads
// `authState.user != null`, so the authenticated shell stayed on screen backed
// by credentials that no longer existed. #85 fixed the next *cold start*; this
// is the same-session half.
//
// These tests assemble the real provider graph - real `ApiClient`, real
// interceptor chain, real `AuthNotifier` - and only swap the two things that
// would otherwise reach a platform channel (SharedPreferences-backed
// `StorageService`, Keychain-backed token store) plus the transport. Nothing
// about the logout path itself is mocked.
//
// Counterfactual, actually run (docs/verification/issue-127/counterfactual.log):
// with the `sessionSink:` argument removed from `authInterceptorProvider` -
// i.e. pre-fix wiring - 3 of these 5 tests fail, each reporting a `User` still
// sitting in `AuthState` after the 401.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_stores.dart';

/// Transport that answers every request with 401, as an expired session does.
class _UnauthorizedAdapter implements HttpClientAdapter {
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits++;
    return ResponseBody.fromString(
      jsonEncode({'error': 'token expired'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The user whose session every test below starts from.
const _seededUser = UserModel(
  id: 'u-1',
  email: 'signed-in@example.com',
  name: 'Signed In',
);

/// A container holding a restored, authenticated session on a fake device.
class _Session {
  _Session(this.container, this.storage, this.tokens, this.adapter);

  final ProviderContainer container;
  final InMemoryStorage storage;
  final InMemoryTokenStore tokens;
  final _UnauthorizedAdapter adapter;

  ApiClient get apiClient => container.read(apiClientProvider);

  AuthState get authState => container.read(authNotifierProvider);
}

void main() {
  /// Builds the real graph, persists a session, and restores it the way a
  /// cold start does - so `AuthState` holds a `User` before anything 401s.
  ///
  /// No refresh token is stored, so `AuthRepositoryImpl.refreshToken()`
  /// short-circuits to a failure without touching the network: that is the
  /// "refresh fails" half of the forced logout, driven by production code
  /// rather than by a stub.
  Future<_Session> signedInSession() async {
    final storage = InMemoryStorage();
    final tokens = InMemoryTokenStore();

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);

    // Persist a session exactly as a successful login does.
    final local = container.read(authLocalDataSourceProvider);
    await local.cacheUser(_seededUser);
    await local.cacheToken('access-token');

    await container.read(authNotifierProvider.notifier).restoreSession();

    // The premise of every test here, asserted rather than assumed.
    expect(
      container.read(authNotifierProvider).user,
      isNotNull,
      reason: 'the app must actually hold a session before the 401 arrives',
    );
    expect(storage.values.containsKey(AppConstants.userDataKey), isTrue);
    expect(tokens.accessToken, 'access-token');

    final adapter = _UnauthorizedAdapter();
    container.read(apiClientProvider).dio.httpClientAdapter = adapter;

    return _Session(container, storage, tokens, adapter);
  }

  /// Drives an authenticated request that 401s, which is what forces a logout.
  ///
  /// `.timeout` makes an uncompleted handler fail fast rather than hang.
  Future<void> drive401(ApiClient apiClient) async {
    await expectLater(
      apiClient.get('/users/me').timeout(const Duration(seconds: 10)),
      throwsA(isA<AppException>()),
      reason: 'the 401 must still surface to the caller that made the request',
    );
  }

  group('forced logout drops the in-memory session (#127 criterion 1)', () {
    test('a 401 whose refresh fails clears AuthState.user', () async {
      final session = await signedInSession();

      await drive401(session.apiClient);

      expect(
        session.authState.user,
        isNull,
        reason:
            'the running app must not keep a User after the transport ended '
            'the session',
      );
      // Nothing else in AuthState is left mid-flight either.
      expect(session.authState.isLoading, isFalse);

      // The persisted teardown the earlier issues added still happened, so the
      // new step was added to the chain rather than in place of one.
      expect(session.tokens.accessToken, isNull);
      expect(
        session.storage.values.containsKey(AppConstants.userDataKey),
        isFalse,
      );
      expect(session.adapter.hits, 1);
    });

    test(
      'the retry-exhausted logout branch clears AuthState.user too',
      () async {
        // A request already carrying X-Retry-Count: 1 takes the early
        // `_logoutUser()` branch in AuthInterceptor, which returns before any
        // refresh is attempted. Both call sites must end the session.
        final session = await signedInSession();

        await expectLater(
          session.apiClient
              .get('/users/me', headers: <String, String>{'X-Retry-Count': '1'})
              .timeout(const Duration(seconds: 10)),
          throwsA(isA<AppException>()),
        );

        expect(session.authState.user, isNull);
        expect(session.tokens.accessToken, isNull);
      },
    );
  });

  group('no DI cycle is introduced (#127 criterion 3)', () {
    test(
      'building the API client does not build the auth notifier',
      () async {
        // The edge that would cycle is notifier -> use case -> repository ->
        // remote data source -> ApiClient -> interceptor -> notifier. The sink
        // defers reading the notifier to call time, so assembling the client
        // must leave the notifier untouched. If this ever fails, the graph is
        // one refactor away from a CircularDependencyError at boot.
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(InMemoryStorage()),
            tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          ],
        );
        addTearDown(container.dispose);

        container.read(apiClientProvider);

        expect(
          container.exists(authNotifierProvider),
          isFalse,
          reason: 'the sink must resolve the notifier lazily, not eagerly',
        );
      },
    );
  });

  group('the router reacts without a restart (#127 criterion 2)', () {
    testWidgets('a forced logout moves the running app to /login', (
      tester,
    ) async {
      final session = await signedInSession();

      // Mount the real router on the restored session, the way main() does.
      final router = session.container.read(goRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: session.container,
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

      // Precondition: the authenticated shell, not /login.
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);

      // `runAsync`: the request has to complete on the real clock. Inside the
      // widget binding's fake one, dio's futures never resolve and the test
      // simply hangs.
      await tester.runAsync(() => drive401(session.apiClient));
      await tester.pumpAndSettle();

      // No imperative navigation from the network layer: the interceptor only
      // changed the auth state, and the existing guard in app_router.dart
      // reacted through its refreshListenable.
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('a forced logout with nobody listening is harmless (#127 c4)', () {
    testWidgets('a 401 after the container is disposed does not throw', (
      tester,
    ) async {
      final storage = InMemoryStorage();
      final tokens = InMemoryTokenStore();
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          tokenStoreProvider.overrideWithValue(tokens),
        ],
      );

      final local = container.read(authLocalDataSourceProvider);
      await local.cacheUser(_seededUser);
      await local.cacheToken('access-token');
      await container.read(authNotifierProvider.notifier).restoreSession();

      final apiClient = container.read(apiClientProvider)
        ..dio.httpClientAdapter = _UnauthorizedAdapter();

      // The app is gone; an in-flight background request is not.
      container.dispose();

      await tester.runAsync(() => drive401(apiClient));
      await tester.pump();

      // Resolving a provider from a disposed container throws; the sink call
      // is guarded, so the request completes normally and nothing escapes.
      expect(tester.takeException(), isNull);
      // And the persisted teardown still ran.
      expect(tokens.accessToken, isNull);
      expect(storage.values.containsKey(AppConstants.userDataKey), isFalse);
    });
  });
}
