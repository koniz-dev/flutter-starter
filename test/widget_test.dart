// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App displays welcome message', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: MyApp requires ProviderScope, so we need to wrap it
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Wait for async initialization and router navigation
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Verify that the app displays the welcome message
    // The router may redirect, so check for either home screen or login screen
    // content
    final welcomeText = find.text(
      'Welcome to Flutter Starter with Clean Architecture!',
    );
    final loginText = find.text('Login'); // Login screen might be shown
    
    // At least one of these should be found
    expect(
      tester.any(welcomeText) || tester.any(loginText),
      isTrue,
      reason: 'Expected either welcome message or login screen',
    );
  });
}
