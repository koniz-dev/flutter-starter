// Tests for the shared test helpers that docs point adopters at but no test
// used. The issue's three broken helpers -
// findWidgetWithText, findTextFormFieldByLabel, waitForCondition - had no
// caller and were deleted rather than fixed, along with the other unused ones.

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_stores.dart';
import 'pump_app.dart';
import 'test_fixtures.dart';
import 'test_helpers.dart';

void main() {
  group('fixtures', () {
    test('createUserModel fills defaults and takes overrides', () {
      final model = createUserModel(id: 'u-1', name: 'Ada');

      expect(model.id, 'u-1');
      expect(model.email, 'test@example.com');
      expect(model.name, 'Ada');
    });

    test('createAuthResponse wraps a user model and both tokens', () {
      final response = createAuthResponse(token: 't-1');

      expect(response.token, 't-1');
      expect(response.refreshToken, 'test-refresh-token');
      expect(response.user.email, 'test@example.com');
    });

    test('createCacheException carries its message', () {
      final exception = createCacheException(message: 'disk full');

      expect(exception, isA<CacheException>());
      expect(exception.message, 'disk full');
    });

    test('createServerException defaults to a 500', () {
      final exception = createServerException();

      expect(exception, isA<ServerException>());
      expect(exception.statusCode, 500);
      expect(exception.code, 'SERVER_ERROR');
    });
  });

  // Used across feature tests too, but covered here so a strip variant that
  // deletes those tests still calls them (the scan in
  // test/tooling/test_helpers_used_test.dart runs in every variant).
  group('result assertions', () {
    test('expectResultSuccess passes on a Success with that data', () {
      expectResultSuccess(const Success(3), 3);
    });

    test('expectResultFailure passes on that failure', () {
      const failure = ServerFailure('boom');
      expectResultFailure(const ResultFailure<int>(failure), failure);
    });
  });

  group('in-memory stores', () {
    test('InMemoryKeyValueStore round-trips, removes and clears', () async {
      final store = InMemoryKeyValueStore();

      expect(await store.setString('k', 'v'), isTrue);
      expect(await store.getString('k'), 'v');
      expect(await store.containsKey('k'), isTrue);
      expect(await store.remove('k'), isTrue);
      expect(await store.getString('k'), isNull);

      await store.setString('a', '1');
      await store.clear();
      expect(await store.containsKey('a'), isFalse);
    });
  });

  group('pumping', () {
    testWidgets('createTestApp hosts a widget under a Scaffold', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp(child: const Text('hosted')));

      expect(find.text('hosted'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('pumpAppAndSettle pumps and settles animations', (
      tester,
    ) async {
      await pumpAppAndSettle(
        tester,
        const AnimatedOpacity(
          opacity: 1,
          duration: Duration(milliseconds: 300),
          child: Text('settled'),
        ),
      );

      expect(find.text('settled'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
