import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTypography Properties Test', () {
    test('FontFamily is a string', () {
      expect(AppTypography.fontFamily, isNotEmpty);
    });

    test('Should expose TextStyle definitions', () {
      expect(AppTypography.displayLarge, isA<TextStyle>());
      expect(AppTypography.headlineMedium, isA<TextStyle>());
      expect(AppTypography.titleMedium, isA<TextStyle>());
      expect(AppTypography.bodyLarge, isA<TextStyle>());
      expect(AppTypography.bodyMedium, isA<TextStyle>());
      expect(AppTypography.labelButton, isA<TextStyle>());
    });
  });
}
