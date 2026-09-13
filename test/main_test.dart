import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression guard for #40. On a real device `pumpAndSettle` never returns,
  // and the natural suspicion is that the app tree schedules frames forever.
  // It does not: under the standard test binding the whole app - router,
  // Riverpod scope, localization and the initial route - reaches an idle frame.
  //
  // That makes this test the control. If it ever starts timing out, something
  // in `lib/` really has begun scheduling frames continuously, and that is a
  // battery and jank bug on device, not just a test problem. The device-side
  // timeout is a property of Patrol's live binding instead; see
  // `test/helpers/pump_app.dart` and `integration_test/README.md`.
  group('full app reaches an idle frame (#40 regression)', () {
    testWidgets('pumpAndSettle on the whole app does not time out', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      // A generous but finite timeout: this throws `pumpAndSettle timed out`
      // rather than hanging if the tree ever stops quiescing.
      final frames = await tester.pumpAndSettle(const Duration(seconds: 10));

      // Settling in a finite number of frames IS the assertion - a tree that
      // schedules frames forever never gets here.
      expect(frames, greaterThan(0));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('MyApp', () {
    testWidgets('should create MyApp widget', (tester) async {
      const myApp = MyApp();
      expect(myApp, isA<ConsumerWidget>());
    });

    testWidgets('should build MaterialApp with correct title', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      // Wait for router to initialize and navigation to complete
      // Use timeout to prevent hanging
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check that MaterialApp is built (title is a property, not displayed
      // text)
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Flutter Starter');
    });

    testWidgets('should use light theme by default', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
    });

    testWidgets('should have dark theme configured', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.darkTheme, isNotNull);
    });

    testWidgets('should configure router correctly', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.routerConfig, isNotNull);
    });

    testWidgets('should configure localization delegates', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.localizationsDelegates, isNotNull);
      expect(materialApp.localizationsDelegates!.length, 4);
    });

    testWidgets('should configure supported locales', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.supportedLocales, isNotNull);
      expect(materialApp.supportedLocales.length, greaterThan(0));
    });

    testWidgets('should use locale from provider', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      await tester.pump();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.locale, isNotNull);
    });

    testWidgets('should configure text direction from provider', (
      tester,
    ) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      await tester.pump();

      // The builder should wrap content in Directionality
      final directionality = find.byType(Directionality);
      expect(directionality, findsWidgets);
    });

    testWidgets('should wrap content in RepaintBoundary', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );

      await tester.pump();

      // The builder should wrap content in RepaintBoundary
      final repaintBoundary = find.byType(RepaintBoundary);
      expect(repaintBoundary, findsWidgets);
    });
  });

  group('HomeScreen', () {
    testWidgets('should create HomeScreen widget', (tester) async {
      const homeScreen = HomeScreen();
      expect(homeScreen, isA<ConsumerWidget>());
    });

    testWidgets('should display welcome message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocalizationService.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );

      expect(
        find.text('Welcome to Flutter Starter with Clean Architecture!'),
        findsOneWidget,
      );
    });

    testWidgets('should have app bar with title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocalizationService.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.text('Flutter Starter'), findsWidgets);
    });
  });
}
