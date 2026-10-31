import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/startup/startup_failure_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A migration failure used to throw before `runApp`,
  // so the user got a black window on every launch with no recovery path.
  group('StartupFailureApp', () {
    testWidgets('renders a screen instead of an empty window', (tester) async {
      await tester.pumpWidget(
        const StartupFailureApp(error: 'migration exploded'),
      );

      expect(find.byKey(StartupFailureApp.bodyKey), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('names the failure and reassures about local data', (
      tester,
    ) async {
      await tester.pumpWidget(
        const StartupFailureApp(error: 'migration exploded'),
      );

      expect(find.text("Couldn't start the app"), findsOneWidget);
      expect(find.textContaining('migration exploded'), findsOneWidget);
      expect(find.textContaining('Nothing has been deleted'), findsOneWidget);
    });

    testWidgets('offers a retry that calls back', (tester) async {
      var retries = 0;

      await tester.pumpWidget(
        StartupFailureApp(
          error: 'migration exploded',
          onRetry: () async => retries++,
        ),
      );

      await tester.tap(find.byKey(StartupFailureApp.retryKey));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('a second tap while a retry is in flight does not retry '
        'again, and the button comes back when it settles', (tester) async {
      var retries = 0;
      final pending = Completer<void>();

      await tester.pumpWidget(
        StartupFailureApp(
          error: 'migration exploded',
          onRetry: () {
            retries++;
            return pending.future;
          },
        ),
      );

      await tester.tap(find.byKey(StartupFailureApp.retryKey));
      await tester.pump();
      await tester.tap(find.byKey(StartupFailureApp.retryKey));
      await tester.pump();

      expect(retries, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(StartupFailureApp.retryKey))
            .onPressed,
        isNull,
      );

      // bootstrap() never throws: a failed retry shows a new failure screen
      // and completes normally.
      pending.complete();
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(StartupFailureApp.retryKey))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('hides retry when no recovery is offered', (tester) async {
      await tester.pumpWidget(
        const StartupFailureApp(error: 'migration exploded'),
      );

      expect(find.byKey(StartupFailureApp.retryKey), findsNothing);
    });
  });
}
