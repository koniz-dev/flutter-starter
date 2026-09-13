import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget with ProviderScope
///
/// This is a convenience function for widget tests that need Riverpod
/// providers.
/// It automatically wraps the widget in ProviderScope and MaterialApp.
///
/// Note that this pumps [widget] inside its *own* `MaterialApp`. It does not
/// boot the real app, so there is no router, no `main()` bootstrap and no
/// navigation observer. To exercise those, pump `MyApp` directly - see
/// `test/main_test.dart`.
///
/// ## `pumpAndSettle` is safe here, but not on a device
///
/// Under the standard test binding (`flutter test`, which is what these helpers
/// run on) `pumpAndSettle` works normally, including on the full app.
///
/// It does **not** work under a live binding on a real device, which is what
/// Patrol uses for `integration_test/`. That is not a property of this app's
/// widget tree - it is how `LiveTestWidgetsFlutterBinding` works. After any
/// frame the test did not itself pump, `handleDrawFrame` calls
/// `platformDispatcher.scheduleFrame()` again for every frame policy except
/// `benchmark`, so a frame is always pending, `hasScheduledFrame` is never
/// false, and the `do { pump } while (hasScheduledFrame)` loop inside
/// `pumpAndSettle` cannot exit. On device it throws `pumpAndSettle timed out`
/// regardless of what the app is doing.
///
/// In `integration_test/`, use Patrol's `waitUntilVisible` (which polls rather
/// than demanding quiescence) instead of `pumpAndSettle`. See
/// `integration_test/README.md` and issue #40.
///
/// Example:
/// ```dart
/// await pumpApp(
///   tester,
///   const LoginScreen(),
///   overrides: [
///     loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
///   ],
/// );
/// ```
Future<void> pumpApp(
  WidgetTester tester,
  Widget widget, {
  dynamic overrides,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // Override type is not exported from riverpod package.
      // When overrides is provided, it's already List<Override> from
      // provider.overrideWithValue(). When null, we pass an empty list.
      // Runtime type is correct.
      // ignore: argument_type_not_assignable
      overrides: overrides ?? <Never>[],
      child: MaterialApp(
        theme: theme ?? ThemeData.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocalizationService.supportedLocales,
        home: Scaffold(body: widget),
      ),
    ),
  );
}

/// Pumps a widget and waits for all animations to settle
///
/// Useful for widget tests that need to wait for animations or async operations
/// to complete before making assertions.
///
/// Example:
/// ```dart
/// await pumpAppAndSettle(
///   tester,
///   const LoginScreen(),
/// );
/// ```
Future<void> pumpAppAndSettle(
  WidgetTester tester,
  Widget widget, {
  dynamic overrides,
  ThemeData? theme,
  Duration? timeout,
}) async {
  await pumpApp(tester, widget, overrides: overrides, theme: theme);
  await tester.pumpAndSettle(timeout ?? const Duration(seconds: 5));
}

/// Pumps a widget multiple times
///
/// Useful for testing state changes that require multiple pump cycles.
///
/// Example:
/// ```dart
/// await pumpAppMultiple(tester, const LoginScreen(), count: 3);
/// ```
Future<void> pumpAppMultiple(
  WidgetTester tester,
  Widget widget, {
  dynamic overrides,
  ThemeData? theme,
  int count = 2,
}) async {
  await pumpApp(tester, widget, overrides: overrides, theme: theme);
  for (var i = 0; i < count; i++) {
    await tester.pump();
  }
}

/// Pumps a widget and waits for a specific duration
///
/// Useful for testing time-based operations or delays.
///
/// Example:
/// ```dart
/// await pumpAppAndWait(
///   tester,
///   const LoginScreen(),
///   duration: Duration(seconds: 2),
/// );
/// ```
Future<void> pumpAppAndWait(
  WidgetTester tester,
  Widget widget, {
  required Duration duration,
  dynamic overrides,
  ThemeData? theme,
}) async {
  await pumpApp(tester, widget, overrides: overrides, theme: theme);
  await tester.pump(duration);
}
