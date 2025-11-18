import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/widgets/loading_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoadingIndicator', () {
    testWidgets('should display loading indicator', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display message when provided', (tester) async {
      // Arrange
      const message = 'Loading...';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(message: message),
          ),
        ),
      );

      // Assert
      expect(find.text(message), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should not display message when null', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );

      // Assert
      expect(find.byType(Text), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should be centered', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );

      // Assert
      final center = tester.widget<Center>(find.byType(Center));
      expect(center, isNotNull);
    });

    group('Edge Cases', () {
      testWidgets('should handle empty message', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoadingIndicator(message: ''),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle long message', (tester) async {
        final longMessage = 'A' * 100;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LoadingIndicator(message: longMessage),
            ),
          ),
        );

        expect(find.text(longMessage), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should have correct column structure', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoadingIndicator(message: 'Loading...'),
            ),
          ),
        );

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.mainAxisAlignment, MainAxisAlignment.center);
        expect(column.children.length, 3); // Indicator, SizedBox, Text
      });

      testWidgets('should have correct spacing when message provided',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoadingIndicator(message: 'Loading...'),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.byType(SizedBox),
        );
        expect(sizedBox.height, 16);
      });
    });
  });
}
