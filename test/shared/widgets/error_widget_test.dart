import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/widgets/error_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppErrorWidget', () {
    testWidgets('should display error message', (tester) async {
      // Arrange
      const errorMessage = 'An error occurred';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(message: errorMessage),
          ),
        ),
      );

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets(
      'should display retry button when onRetry is provided',
      (tester) async {
      // Arrange
      var retryCalled = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(
              message: 'Error',
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Test retry callback
      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });

    testWidgets(
      'should not display retry button when onRetry is null',
      (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(message: 'Error'),
          ),
        ),
      );

      // Assert
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('should use error color from theme', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: AppErrorWidget(message: 'Error'),
          ),
        ),
      );

      // Assert
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, isNotNull);
    });
  });
}
