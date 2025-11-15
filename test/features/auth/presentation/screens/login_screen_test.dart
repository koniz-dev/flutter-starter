import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

void main() {
  group('LoginScreen', () {
    late MockLoginUseCase mockLoginUseCase;

    setUp(() {
      mockLoginUseCase = MockLoginUseCase();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      );
    }

    testWidgets('should display email and password fields', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('should show validation error for empty email', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Assert
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets(
      'should show validation error for invalid email',
      (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextFormField).first;

        // Act
        await tester.enterText(emailField, 'invalid-email');
        await tester.tap(find.text('Login'));
        await tester.pump();

        // Assert
        expect(
          find.text('Please enter a valid email address'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'should show validation error for empty password',
      (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextFormField).first;

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.tap(find.text('Login'));
        await tester.pump();

        // Assert
        expect(find.text('Please enter your password'), findsOneWidget);
      },
    );

    testWidgets(
      'should show validation error for short password',
      (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextFormField).first;
        final passwordField = find.byType(TextFormField).last;

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'short');
        await tester.tap(find.text('Login'));
        await tester.pump();

        // Assert
        expect(
          find.text('Password must be at least 8 characters'),
          findsOneWidget,
        );
      },
    );

    testWidgets('should call login when form is valid', (tester) async {
      // Arrange
      const user = User(
        id: '1',
        email: 'test@example.com',
        name: 'Test User',
      );
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) async => const Success(user));

      await tester.pumpWidget(createTestWidget());
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      // Act
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Assert
      verify(() => mockLoginUseCase('test@example.com', 'password123'))
          .called(1);
    });

    testWidgets(
      'should display error message on login failure',
      (tester) async {
        // Arrange
        const failure = AuthFailure('Invalid credentials');
        when(() => mockLoginUseCase(any(), any()))
            .thenAnswer((_) async => const ResultFailure(failure));

        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextFormField).first;
        final passwordField = find.byType(TextFormField).last;

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'password123');
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Invalid credentials'), findsOneWidget);
      },
    );

    testWidgets('should show loading indicator during login', (tester) async {
      // Arrange
      const user = User(
        id: '1',
        email: 'test@example.com',
      );
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) async => const Success(user));

      await tester.pumpWidget(createTestWidget());
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      // Act
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.text('Login'));
      await tester.pump(); // Don't settle, check loading state

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login'), findsNothing);
    });

    testWidgets('should disable button during loading', (tester) async {
      // Arrange
      const user = User(
        id: '1',
        email: 'test@example.com',
      );
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) async => const Success(user));

      await tester.pumpWidget(createTestWidget());
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      // Act
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Assert
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    // Note: Navigation test removed as it requires full app setup
    // For widget tests, focus on UI validation and form behavior
  });
}
