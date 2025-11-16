import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
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
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocalizationService.supportedLocales,
          home: const LoginScreen(),
        ),
      );
    }

    testWidgets('should display email and password fields', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('should show validation error for empty email', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
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
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
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
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
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
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
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
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
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
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
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
      final completer = Completer<Result<User>>();
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget());
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      // Act
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump(); // Don't settle, check loading state

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The button text is replaced with CircularProgressIndicator
      // during loading
      expect(find.text('Login'), findsNWidgets(1)); // Only in AppBar title

      // Complete the login to clean up
      completer.complete(const Success(user));
      await tester.pumpAndSettle();
    });

    testWidgets('should disable button during loading', (tester) async {
      // Arrange
      const user = User(
        id: '1',
        email: 'test@example.com',
      );
      final completer = Completer<Result<User>>();
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget());
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      // Act
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      // Pump to trigger the login action and state update
      await tester.pump();

      // Assert - When loading, the button shows CircularProgressIndicator
      // instead of text. This indicates the button is in a
      // loading/disabled state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The button text "Login" should not be visible in the button
      // (only in AppBar)
      expect(find.text('Login'), findsNWidgets(1)); // Only in AppBar title

      // Complete the login to clean up
      completer.complete(const Success(user));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'should navigate to RegisterScreen when register button is tapped',
      (tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());

        // Act
        await tester.tap(find.text("Don't have an account? Register"));
        await tester.pumpAndSettle();

        // Assert
        // Verify RegisterScreen is displayed
        expect(find.text('Register'), findsWidgets);
        expect(find.text('Name'), findsOneWidget);
      },
    );
  });
}
