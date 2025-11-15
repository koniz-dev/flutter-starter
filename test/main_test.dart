import 'package:flutter/material.dart';

import 'package:flutter_starter/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MyApp', () {
    testWidgets('should create MyApp widget', (tester) async {
      const myApp = MyApp();
      expect(myApp, isA<StatelessWidget>());
    });

    testWidgets('should build MaterialApp with correct title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MyApp(),
        ),
      );

      expect(find.text('Flutter Starter'), findsWidgets);
    });

    testWidgets('should use light theme by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MyApp(),
        ),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
    });

    testWidgets('should have dark theme configured', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MyApp(),
        ),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.darkTheme, isNotNull);
    });
  });

  group('HomeScreen', () {
    testWidgets('should create HomeScreen widget', (tester) async {
      const homeScreen = HomeScreen();
      expect(homeScreen, isA<StatelessWidget>());
    });

    testWidgets('should display welcome message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(
        find.text('Welcome to Flutter Starter with Clean Architecture!'),
        findsOneWidget,
      );
    });

    testWidgets('should have app bar with title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.text('Flutter Starter'), findsWidgets);
    });
  });
}
