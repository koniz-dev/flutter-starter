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

    // Wait for async initialization
    await tester.pumpAndSettle();

    // Verify that the app displays the welcome message
    expect(
      find.text('Welcome to Flutter Starter with Clean Architecture!'),
      findsOneWidget,
    );
    expect(find.text('Flutter Starter'), findsOneWidget); // AppBar title
  });
}
