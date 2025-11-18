import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a test MaterialApp with ProviderScope
///
/// Useful for widget tests that need Riverpod providers.
/// Optionally override providers for testing.
Widget createTestApp({
  required Widget child,
  dynamic overrides,
  ThemeData? theme,
}) {
  return ProviderScope(
    // Override type is not exported from riverpod package.
    // When overrides is provided, it's already List<Override> from
    // provider.overrideWithValue(). When null, we pass an empty list.
    // Runtime type is correct.
    // ignore: argument_type_not_assignable
    overrides: overrides ?? <Never>[],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps widget and waits for animations to complete
///
/// Useful for widget tests that need to wait for animations or async
/// operations.
Future<void> pumpAndSettleApp(
  WidgetTester tester,
  Widget widget, {
  Duration? timeout,
}) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle(timeout ?? const Duration(seconds: 5));
}

/// Asserts that a Result is a Success with expected data
void expectResultSuccess<T>(
  Result<T> result,
  T expectedData,
) {
  expect(result.isSuccess, isTrue, reason: 'Expected success but got failure');
  expect(result.dataOrNull, expectedData);
}

/// Asserts that a Result is a Failure with expected failure
void expectResultFailure<T>(
  Result<T> result,
  Failure expectedFailure,
) {
  expect(result.isFailure, isTrue, reason: 'Expected failure but got success');
  expect(result.failureOrNull, expectedFailure);
}

/// Asserts that a Result is a Failure of specific type
void expectResultFailureType<T>(
  Result<T> result,
  Type failureType,
) {
  expect(result.isFailure, isTrue, reason: 'Expected failure but got success');
  expect(result.failureOrNull, isA<Failure>());
  expect(result.failureOrNull?.runtimeType, failureType);
}

/// Asserts that a Result is a Failure with expected message
void expectResultFailureMessage<T>(
  Result<T> result,
  String expectedMessage,
) {
  expect(result.isFailure, isTrue, reason: 'Expected failure but got success');
  expect(result.failureOrNull?.message, expectedMessage);
}

/// Waits for async operations to complete
///
/// Useful for tests that need to wait for Future operations.
Future<void> waitForAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Finds a widget by type and text
Finder findWidgetWithText(Type widgetType, String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget.runtimeType == widgetType &&
        widget is Text &&
        widget.data == text,
  );
}

/// Finds a TextFormField by label text
///
/// Note: This is a placeholder implementation. TextFormField decoration
/// is not directly accessible in widget tests. Consider using
/// find.byType(TextFormField) with index (e.g., .first, .last) or
/// find.text(label) to find the label text widget instead.
Finder findTextFormFieldByLabel(String label) {
  // TextFormField decoration is not accessible in widget tests.
  // Return a finder that looks for Text widgets with the label text
  // positioned near TextFormField widgets.
  return find.byWidgetPredicate(
    (widget) {
      if (widget is! Text) return false;
      return widget.data == label;
    },
  );
}

/// Creates a mock provider override
///
/// Example:
/// ```dart
/// final overrides = [
///   createProviderOverride(loginUseCaseProvider, mockLoginUseCase),
/// ];
/// ```
///
/// Note: This is a convenience wrapper around provider.overrideWithValue().
/// The return type uses dynamic because Override is not exported from riverpod.
dynamic createProviderOverride<T>(
  Provider<T> provider,
  T mockValue,
) {
  return provider.overrideWithValue(mockValue);
}

/// Helper to register fallback values for mocktail
///
/// Call this in setUpAll() to register fallback values for complex types.
void registerFallbackValues() {
  // Add fallback values here as needed
  // Example: registerFallbackValue(FakeUserModel());
}

/// Creates a test user for testing
///
/// Returns a User entity with test data.
/// Can be customized with optional parameters.
User createTestUser({
  String id = 'test-id',
  String email = 'test@example.com',
  String? name,
  String? avatarUrl,
}) {
  return User(
    id: id,
    email: email,
    name: name ?? 'Test User',
    avatarUrl: avatarUrl,
  );
}

/// Waits for a specific condition to be true
///
/// Useful for waiting for async state changes in tests.
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    if (condition()) return;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException('Condition not met within timeout');
}

/// Asserts that a widget is displayed
void expectWidgetDisplayed(Finder finder, String description) {
  expect(finder, findsOneWidget, reason: '$description should be displayed');
}

/// Asserts that a widget is not displayed
void expectWidgetNotDisplayed(Finder finder, String description) {
  expect(finder, findsNothing, reason: '$description should not be displayed');
}

/// Asserts that text is displayed
void expectTextDisplayed(String text) {
  expect(
    find.text(text),
    findsOneWidget,
    reason: 'Text "$text" should be displayed',
  );
}

/// Asserts that text is not displayed
void expectTextNotDisplayed(String text) {
  expect(
    find.text(text),
    findsNothing,
    reason: 'Text "$text" should not be displayed',
  );
}
