@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/startup/startup_failure_app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'acceptance_helpers.dart';

void main() {
  // Criterion 7 of #60: a failed storage migration must not leave the user
  // with a blank window. `StartupFailureApp` is itself the root app (it stands
  // in for the `MyApp` that never got built), so it is pumped directly rather
  // than through `pumpAcceptance`, which would nest a second MaterialApp.
  group('StartupFailureApp acceptance', () {
    testWidgets('paints a recovery screen instead of an empty window', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(kAcceptanceSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        StartupFailureApp(
          error: MigrationPathStub(),
          onRetry: () async {},
        ),
      );
      await tester.pumpAndSettle();

      // Text content has to be asserted with finders: the golden renders
      // every glyph as an opaque block.
      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(find.byKey(StartupFailureApp.retryKey), findsOneWidget);
      expect(find.text("Couldn't start the app"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // The golden proves something actually paints, and where.
      await captureAcceptanceGolden(
        find.byType(StartupFailureApp),
        'startup_failure',
      );
    });
  });
}

/// Stands in for a real `MigrationPathException` without importing the
/// storage layer into a presentation golden.
class MigrationPathStub {
  @override
  String toString() =>
      'MigrationPathException: No migration path from v1 to v2';
}
