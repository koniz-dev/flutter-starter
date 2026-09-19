import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeatureFlagsManager extends Mock implements FeatureFlagsManager {}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

// Reachability, not route-table shape: this pumps the *app's* router and
// asserts the debug screen renders. Until #56 `AppRoutes.featureFlagsDebug`
// and `context.goToFeatureFlagsDebug()` existed while `routes_registry.dart`
// registered no route for either.

void main() {
  late _MockFeatureFlagsManager manager;
  late ProviderContainer container;

  setUp(() {
    manager = _MockFeatureFlagsManager();
    when(() => manager.refresh()).thenAnswer((_) async {});
  });

  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _TestAuthNotifier(
            const AuthState(
              user: User(id: '1', email: 'test@example.com'),
            ),
          ),
        ),
        sessionRestorationProvider.overrideWith((ref) async {}),
        featureFlagsManagerProvider.overrideWithValue(manager),
        allFeatureFlagsProvider.overrideWith(
          (ref) => Future<Map<String, FeatureFlag?>>.value({}),
        ),
      ],
    );
    addTearDown(container.dispose);

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
    await tester.pumpAndSettle();
    return router;
  }

  group('AppRoutes feature flags constants', () {
    test('path and name are the ones the route module registers', () {
      expect(AppRoutes.featureFlagsDebug, '/feature-flags-debug');
      expect(AppRoutes.featureFlagsDebugName, 'feature-flags-debug');
    });
  });

  group('buildFeatureFlagsRoutes', () {
    test('is composed into the app route tree', () {
      final probe = ProviderContainer();
      addTearDown(probe.dispose);
      final routes = probe.read(Provider<List<RouteBase>>(buildAppRoutes));

      final debug = routes.whereType<GoRoute>().firstWhere(
        (route) => route.path == AppRoutes.featureFlagsDebug,
        orElse: () =>
            throw StateError('Feature flags debug route not registered'),
      );

      expect(debug.name, AppRoutes.featureFlagsDebugName);
    });
  });

  group('the debug route is reachable from the running app', () {
    testWidgets('goToFeatureFlagsDebug renders the debug screen', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      tester.element(find.byType(Scaffold).last).goToFeatureFlagsDebug();
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.featureFlagsDebug);
      expect(find.byType(FeatureFlagsDebugScreen), findsOneWidget);
    });
  });
}
