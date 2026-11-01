import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/signed_in_app.dart';

/// A server that holds every logout call until [release].
class _SlowLogoutRemote implements AuthRemoteDataSource {
  final List<String?> calls = [];
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> logout({String? refreshToken}) {
    calls.add(refreshToken);
    return _gate.future;
  }

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

void main() {
  testWidgets('signing out from home clears the session and lands on login', (
    tester,
  ) async {
    final app = await pumpSignedInApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byKey(UiKeys.homeSignOut));
    await tester.pumpAndSettle();

    expect(app.router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(app.container.read(authProvider).user, isNull);
    // The stored session, not only the in-memory one, is gone.
    expect(app.session, isA<InMemorySessionDataSource>());
    expect(app.session.token, isNull);
    expect(app.session.refresh, isNull);
    expect(app.session.user, isNull);
  });

  testWidgets('a second tap while signing out sends no second logout', (
    tester,
  ) async {
    final remote = _SlowLogoutRemote();
    final app = await pumpSignedInApp(tester, remote: remote);

    await tester.tap(find.byKey(UiKeys.homeSignOut));
    await tester.pump();
    final button = tester.widget<IconButton>(find.byKey(UiKeys.homeSignOut));
    expect(button.onPressed, isNull, reason: 'disabled while in flight');
    await tester.tap(find.byKey(UiKeys.homeSignOut), warnIfMissed: false);
    await tester.pump();

    remote.release();
    await tester.pumpAndSettle();

    expect(remote.calls, hasLength(1));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(app.container.read(authProvider).error, isNull);
  });
}
