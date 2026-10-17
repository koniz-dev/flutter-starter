import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
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

/// Asserts that a Result is a Success with expected data
void expectResultSuccess<T>(Result<T> result, T expectedData) {
  expect(result.isSuccess, isTrue, reason: 'Expected success but got failure');
  expect(result.dataOrNull, expectedData);
}

/// Asserts that a Result is a Failure with expected failure
void expectResultFailure<T>(Result<T> result, Failure expectedFailure) {
  expect(result.isFailure, isTrue, reason: 'Expected failure but got success');
  expect(result.failureOrNull, expectedFailure);
}

/// Asserts that a Result is a Failure of specific type
void expectResultFailureType<T>(Result<T> result, Type failureType) {
  expect(result.isFailure, isTrue, reason: 'Expected failure but got success');
  expect(result.failureOrNull, isA<Failure>());
  expect(result.failureOrNull?.runtimeType, failureType);
}
