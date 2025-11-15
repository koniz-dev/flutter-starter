import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('should have lightTheme', () {
      expect(AppTheme.lightTheme, isA<ThemeData>());
    });

    test('lightTheme should use Material 3', () {
      expect(AppTheme.lightTheme.useMaterial3, isTrue);
    });

    test('lightTheme should have colorScheme', () {
      expect(AppTheme.lightTheme.colorScheme, isA<ColorScheme>());
    });

    test('lightTheme should have textTheme', () {
      expect(AppTheme.lightTheme.textTheme, isA<TextTheme>());
    });

    test('lightTheme should have appBarTheme', () {
      expect(AppTheme.lightTheme.appBarTheme, isA<AppBarTheme>());
    });

    test('lightTheme should have elevatedButtonTheme', () {
      expect(
        AppTheme.lightTheme.elevatedButtonTheme,
        isA<ElevatedButtonThemeData>(),
      );
    });

    test('lightTheme should have inputDecorationTheme', () {
      expect(
        AppTheme.lightTheme.inputDecorationTheme,
        isA<InputDecorationTheme>(),
      );
    });

    test('should have darkTheme', () {
      expect(AppTheme.darkTheme, isA<ThemeData>());
    });

    test('darkTheme should use Material 3', () {
      expect(AppTheme.darkTheme.useMaterial3, isTrue);
    });

    test('darkTheme should have colorScheme', () {
      expect(AppTheme.darkTheme.colorScheme, isA<ColorScheme>());
    });

    test('darkTheme should have textTheme', () {
      expect(AppTheme.darkTheme.textTheme, isA<TextTheme>());
    });

    test('darkTheme should have appBarTheme', () {
      expect(AppTheme.darkTheme.appBarTheme, isA<AppBarTheme>());
    });

    test('darkTheme should have elevatedButtonTheme', () {
      expect(
        AppTheme.darkTheme.elevatedButtonTheme,
        isA<ElevatedButtonThemeData>(),
      );
    });

    test('darkTheme should have inputDecorationTheme', () {
      expect(
        AppTheme.darkTheme.inputDecorationTheme,
        isA<InputDecorationTheme>(),
      );
    });

    test('lightTheme and darkTheme should be different', () {
      expect(
        AppTheme.lightTheme.scaffoldBackgroundColor,
        isNot(AppTheme.darkTheme.scaffoldBackgroundColor),
      );
    });
  });
}
