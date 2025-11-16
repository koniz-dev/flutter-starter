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
