// Tests for the shared test helpers that docs point adopters at but no test
// used (koniz-dev/flutter-starter#375). The issue's three broken helpers -
// findWidgetWithText, findTextFormFieldByLabel, waitForCondition - had no
// caller and were deleted rather than fixed, along with the other unused ones.

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('createServerException defaults to a 500', () {
      final exception = createServerException();

      expect(exception, isA<ServerException>());
      expect(exception.statusCode, 500);
      expect(exception.code, 'SERVER_ERROR');
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
