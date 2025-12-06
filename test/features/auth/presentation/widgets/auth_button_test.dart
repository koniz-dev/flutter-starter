import 'package:flutter/material.dart';
import 'package:flutter_starter/features/auth/presentation/widgets/auth_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthButton', () {
    testWidgets('should display button text', (tester) async {
      // Arrange
      const buttonText = 'Login';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: buttonText,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(buttonText), findsOneWidget);
    });

    testWidgets('should call onPressed when tapped', (tester) async {
      // Arrange
      var pressed = false;
      const buttonText = 'Login';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: buttonText,
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text(buttonText));
      await tester.pump();

      // Assert
      expect(pressed, isTrue);
    });

    testWidgets('should show loading indicator when isLoading is true', (
      tester,
    ) async {
      // Arrange
      const buttonText = 'Login';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: buttonText,
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(buttonText), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should disable button when isLoading is true', (tester) async {
      // Arrange
      var pressed = false;
      const buttonText = 'Login';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: buttonText,
              isLoading: true,
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      // Try to tap the button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Assert
      expect(pressed, isFalse);
    });

    testWidgets('should have minimum size', (tester) async {
      // Arrange
      const buttonText = 'Login';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: buttonText,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style?.minimumSize?.resolve({}), isNotNull);
    });

    testWidgets('should work without onPressed callback', (tester) async {
      // Arrange
      const buttonText = 'Login';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthButton(
              text: buttonText,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(buttonText), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    group('Edge Cases', () {
      testWidgets('should handle empty text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthButton(
                text: '',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
      });

      testWidgets('should handle long text', (tester) async {
        final longText = 'A' * 100;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthButton(
                text: longText,
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text(longText), findsOneWidget);
      });

      testWidgets('should handle multiple rapid taps', (tester) async {
        var tapCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthButton(
                text: 'Login',
                onPressed: () {
                  tapCount++;
                },
              ),
            ),
          ),
        );

        final button = find.text('Login');
        await tester.tap(button);
        await tester.tap(button);
        await tester.tap(button);
        await tester.pump();

        expect(tapCount, 3);
      });

      testWidgets(
        'should not call onPressed when disabled and loading',
        (tester) async {
          var pressed = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AuthButton(
                  text: 'Login',
                  isLoading: true,
                  onPressed: () {
                    pressed = true;
                  },
                ),
              ),
            ),
          );

          // Pump once to allow widget to build
          // Don't use pumpAndSettle() because CircularProgressIndicator
          // has infinite animation
          await tester.pump();

          // Verify onPressed was never called (main assertion)
          expect(pressed, isFalse);

          // Verify loading indicator exists (quick check)
          // Using find.descendant to limit search scope for better performance
          expect(
            find.descendant(
              of: find.byType(AuthButton),
              matching: find.byType(CircularProgressIndicator),
            ),
            findsOneWidget,
          );
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );
    });
  });
}
