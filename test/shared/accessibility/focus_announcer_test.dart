import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/accessibility/focus_announcer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FocusAnnouncer', () {
    testWidgets('should announce message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestWidget(),
          ),
        ),
      );

      final context = tester.element(find.byType(_TestWidget));

      // Should not throw
      expect(
        () => FocusAnnouncer.announce(context, 'Test message'),
        returnsNormally,
      );
    });

    testWidgets('should announce with assertiveness', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestWidget(),
          ),
        ),
      );

      final context = tester.element(find.byType(_TestWidget));

      expect(
        () => FocusAnnouncer.announce(
          context,
          'Test message',
          assertiveness: true,
        ),
        returnsNormally,
      );
    });

    testWidgets('should announce focus change', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestWidget(),
          ),
        ),
      );

      final context = tester.element(find.byType(_TestWidget));

      expect(
        () => FocusAnnouncer.announceFocusChange(context, 'Button'),
        returnsNormally,
      );
    });

    testWidgets('should announce page change', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestWidget(),
          ),
        ),
      );

      final context = tester.element(find.byType(_TestWidget));

      expect(
        () => FocusAnnouncer.announcePageChange(context, 'Home Page'),
        returnsNormally,
      );
    });

    testWidgets('should announce action result', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestWidget(),
          ),
        ),
      );

      final context = tester.element(find.byType(_TestWidget));

      expect(
        () => FocusAnnouncer.announceActionResult(context, 'Action completed'),
        returnsNormally,
      );
    });
  });
}

class _TestWidget extends StatelessWidget {
  const _TestWidget();

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
