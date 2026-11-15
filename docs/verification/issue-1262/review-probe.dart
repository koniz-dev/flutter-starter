import 'dart:async';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../test/helpers/in_memory_stores.dart';

class _HeldRemote extends Mock implements AuthRemoteDataSource {
  final release = Completer<void>();
  int calls = 0;
  String? capturedAccess;
  String? capturedRefresh;

  @override
  Future<void> logout({String? refreshToken, String? accessToken}) {
    calls++;
    capturedAccess = accessToken;
    capturedRefresh = refreshToken;
    return release.future;
  }
}

typedef _Session = ({
  ProviderContainer container,
  GoRouter router,
  InMemoryStorage storage,
  InMemoryTokenStore tokens,
  _HeldRemote remote,
});

Future<_Session> _mountSignedIn(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 3000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final storage = InMemoryStorage();
  final tokens = InMemoryTokenStore();
  final remote = _HeldRemote();
  final container = ProviderContainer(
    overrides: [
      ...authModuleOverrides,
      storageServiceProvider.overrideWithValue(storage),
      tokenStoreProvider.overrideWithValue(tokens),
      authRemoteDataSourceProvider.overrideWithValue(remote),
    ],
  );
  addTearDown(container.dispose);
  final local = container.read(authLocalDataSourceProvider);
  await local.cacheUser(const UserModel(id: 'A', email: 'a@example.com'));
  await local.cacheToken('access-A');
  await local.cacheRefreshToken('refresh-A');
  await container.read(sessionRestorationProvider.future);
  final router = container.read(goRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('en'),
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('en')],
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(container.read(authNotifierProvider).user, isNotNull);
  return (
    container: container,
    router: router,
    storage: storage,
    tokens: tokens,
    remote: remote,
  );
}

// An outstanding logout keeps the auth loading indicator animated. Pump the
// router transition explicitly rather than waiting for animation settlement.
Future<void> _pumpRedirect(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void _expectLocalTeardown(_Session session) {
  expect(session.remote.calls, 1);
  expect(session.remote.capturedAccess, 'access-A');
  expect(session.remote.capturedRefresh, 'refresh-A');
  expect(session.tokens.accessToken, isNull);
  expect(session.tokens.refreshToken, isNull);
  expect(session.storage.values.containsKey(AppConstants.userDataKey), isFalse);
}

void main() {
  for (final remoteFails in [false, true]) {
    testWidgets('queued sign-in survives logout completion failure=$remoteFails', (tester) async {
      final session = await _mountSignedIn(tester);
      final notifier = session.container.read(authNotifierProvider.notifier);
      var loginCalls = 0;
      when(() => session.remote.login('b@example.com', 'password')).thenAnswer((_) async {
        loginCalls++;
        return const AuthResponseModel(user: UserModel(id: 'B', email: 'b@example.com'), token: 'access-B', refreshToken: 'refresh-B');
      });
      final logout = notifier.logout();
      await _pumpRedirect(tester);
      expect(session.container.read(authNotifierProvider).isLoading, isTrue);
      final button = tester.widget<ElevatedButton>(find.byKey(UiKeys.loginSubmit));
      expect(button.onPressed, isNull);
      final login = notifier.login('b@example.com', 'password');
      await tester.pump();
      expect(loginCalls, 0);
      if (remoteFails) {
        session.remote.release.completeError(const ServerException('old logout failed', statusCode: 503));
      } else {
        session.remote.release.complete();
      }
      await logout;
      await login;
      await tester.pumpAndSettle();
      expect(loginCalls, 1);
      final state = session.container.read(authNotifierProvider);
      expect(state.user?.id, 'B');
      expect(state.isLoading, isFalse);
      expect(state.failure, isNull);
      expect(session.tokens.accessToken, 'access-B');
      expect(session.router.routeInformationProvider.value.uri.path, AppRoutes.home);
    });
  }

  testWidgets('sign-out leaves Home while the remote logout is held forever', (
    tester,
  ) async {
    final session = await _mountSignedIn(tester);
    try {
      await tester.tap(find.byKey(UiKeys.homeSignOut));
      await _pumpRedirect(tester);
      _expectLocalTeardown(session);
      expect(session.remote.release.isCompleted, isFalse);
      expect(session.container.read(authNotifierProvider).user, isNull);
      expect(
        session.router.routeInformationProvider.value.uri.path,
        AppRoutes.login,
      );
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    } finally {
      session.remote.release.complete();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'the sign-out caller still receives the later remote failure in state',
    (tester) async {
      final session = await _mountSignedIn(tester);
      final pending = session.container.read(signOutProvider)();
      try {
        await _pumpRedirect(tester);
        _expectLocalTeardown(session);
        expect(session.container.read(authNotifierProvider).user, isNull);
        session.remote.release.completeError(
          const ServerException(
            'revocation unavailable',
            statusCode: 503,
          ),
        );
        await pending;
        await tester.pumpAndSettle();
        final state = session.container.read(authNotifierProvider);
        expect(state.user, isNull);
        expect(state.isLoading, isFalse);
        expect(state.error, 'revocation unavailable');
        expect(state.failure, isA<ServerFailure>());
        expect(
          find.text(lookupAppLocalizations(const Locale('en')).failureServer),
          findsOneWidget,
        );
        expect(
          session.router.routeInformationProvider.value.uri.path,
          AppRoutes.login,
        );
      } finally {
        if (!session.remote.release.isCompleted) {
          session.remote.release.complete();
        }
        await pending;
        await tester.pumpAndSettle();
      }
    },
  );
}
