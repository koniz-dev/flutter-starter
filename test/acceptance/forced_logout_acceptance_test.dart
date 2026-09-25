@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/in_memory_stores.dart';
import 'acceptance_helpers.dart';

/// Visual evidence for #127 criterion 2: the screen a running app is showing
/// before and after the transport forces a logout, with no restart in between.
///
/// Remember what these PNGs can and cannot prove (see acceptance_helpers.dart):
/// every glyph is an opaque Ahem block, so the screen *identity* is asserted
/// with `find.byType` below and the golden only shows which screen was laid
/// out. `forced_logout_after.png` is evidence that the authenticated shell was
/// replaced by the login screen - not that any word on it reads "Login".

/// Transport that answers every request with 401, as an expired session does.
class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'error': 'token expired'}),
    401,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('a forced logout replaces the authenticated shell with login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(kAcceptanceSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = InMemoryStorage();
    final tokens = InMemoryTokenStore();
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);

    // A signed-in device, restored the way a cold start restores it. No refresh
    // token is stored, so the refresh that the 401 triggers fails through
    // production code rather than through a stub.
    final local = container.read(authLocalDataSourceProvider);
    await local.cacheUser(
      const UserModel(
        id: 'u-1',
        email: 'signed-in@example.com',
        name: 'Signed In',
      ),
    );
    await local.cacheToken('access-token');
    await container.read(authNotifierProvider.notifier).restoreSession();

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

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    await captureAcceptanceGolden(
      find.byType(MaterialApp),
      'forced_logout_before',
    );

    final apiClient = container.read(apiClientProvider)
      ..dio.httpClientAdapter = _UnauthorizedAdapter();

    // `runAsync`: the request must complete on the real clock. Inside the
    // widget binding's fake one, dio's futures never resolve and this hangs.
    await tester.runAsync(
      () => expectLater(
        apiClient.get('/users/me').timeout(const Duration(seconds: 10)),
        throwsA(isA<AppException>()),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await captureAcceptanceGolden(
      find.byType(MaterialApp),
      'forced_logout_after',
    );
  });
}
