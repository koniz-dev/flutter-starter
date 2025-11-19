import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_factories.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_fixtures.dart';

void main() {
  group('RegisterScreen', () {
    late MockRegisterUseCase mockRegisterUseCase;

    setUp(() {
      mockRegisterUseCase = createMockRegisterUseCase();
    });

    // Override type is not exported from riverpod package.
    dynamic getOverrides() {
      return [
        registerUseCaseProvider.overrideWithValue(mockRegisterUseCase),
      ];
    }

    testWidgets('should display registration form fields', (tester) async {
      // Arrange & Act
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Assert
      // Check AppBar title
      expect(find.text('Register'), findsWidgets); // AppBar title and button
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
    });

    testWidgets('should show validation error for empty name', (tester) async {
      // Arrange
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(find.text('Please enter your name'), findsOneWidget);
    });

    testWidgets('should show validation error for short name', (tester) async {
      // Arrange
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Act
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'A');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('should show validation error for invalid email',
        (tester) async {
      // Arrange
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Act
      final nameField = find.byType(TextFormField).first;
      final emailField = find.byType(TextFormField).at(1);
      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'invalid-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('should show validation error for short password',
        (tester) async {
      // Arrange
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Act
      final nameField = find.byType(TextFormField).first;
      final emailField = find.byType(TextFormField).at(1);
      final passwordField = find.byType(TextFormField).at(2);
      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'short');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('should call register use case with correct parameters',
        (tester) async {
      // Arrange
      final user = createUser();
      when(() => mockRegisterUseCase(any(), any(), any()))
          .thenAnswer((_) async => Success(user));
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Act
      final nameField = find.byType(TextFormField).first;
      final emailField = find.byType(TextFormField).at(1);
      final passwordField = find.byType(TextFormField).at(2);
      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();

      // Assert
      verify(
        () => mockRegisterUseCase(
          'test@example.com',
          'password123',
          'Test User',
        ),
      ).called(1);
    });

    testWidgets('should show loading indicator during registration',
        (tester) async {
      // Arrange
      final user = createUser();
      when(() => mockRegisterUseCase(any(), any(), any()))
          .thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return Success(user);
      });
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Act
      final nameField = find.byType(TextFormField).first;
      final emailField = find.byType(TextFormField).at(1);
      final passwordField = find.byType(TextFormField).at(2);
      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      // Pump to start the async operation
      await tester.pump();
      // Assert loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Wait for the async operation to complete
      await tester.pumpAndSettle();
    });

    testWidgets('should show error message when registration fails',
        (tester) async {
      // Arrange
      final failure = createAuthFailure(message: 'Registration failed');
      when(() => mockRegisterUseCase(any(), any(), any()))
          .thenAnswer((_) async => ResultFailure(failure));
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: getOverrides(),
      );

      // Act
      final nameField = find.byType(TextFormField).first;
      final emailField = find.byType(TextFormField).at(1);
      final passwordField = find.byType(TextFormField).at(2);
      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Registration failed'), findsOneWidget);
    });

    testWidgets('should navigate back to login when back button is tapped',
        (tester) async {
      // Arrange
      final router = GoRouter(
        initialLocation: AppRoutes.register,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: AppRoutes.register,
            builder: (context, state) => const RegisterScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          // Override type is not exported from riverpod package.
          // ignore: argument_type_not_assignable
          overrides: getOverrides(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocalizationService.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Already have an account? Login'));
      await tester.pumpAndSettle();

      // Assert
      // Verify LoginScreen is displayed
      expect(find.text('Login'), findsWidgets);
      expect(find.text('Email'), findsOneWidget);
    });
  });
}
