import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTypography', () {
    test('should have displayLarge style', () {
      expect(AppTypography.displayLarge, isA<TextStyle>());
      expect(AppTypography.displayLarge.fontSize, 32);
      expect(AppTypography.displayLarge.fontWeight, FontWeight.bold);
    });

    test('should have headlineMedium style', () {
      expect(AppTypography.headlineMedium, isA<TextStyle>());
      expect(AppTypography.headlineMedium.fontSize, 24);
      expect(AppTypography.headlineMedium.fontWeight, FontWeight.w600);
    });

    test('should have titleMedium style', () {
      expect(AppTypography.titleMedium, isA<TextStyle>());
      expect(AppTypography.titleMedium.fontSize, 18);
      expect(AppTypography.titleMedium.fontWeight, FontWeight.w500);
    });

    test('should have bodyLarge style', () {
      expect(AppTypography.bodyLarge, isA<TextStyle>());
      expect(AppTypography.bodyLarge.fontSize, 16);
      expect(AppTypography.bodyLarge.fontWeight, FontWeight.normal);
    });

    test('should have bodyMedium style', () {
      expect(AppTypography.bodyMedium, isA<TextStyle>());
      expect(AppTypography.bodyMedium.fontSize, 14);
      expect(AppTypography.bodyMedium.fontWeight, FontWeight.normal);
    });

    test('should have labelButton style', () {
      expect(AppTypography.labelButton, isA<TextStyle>());
      expect(AppTypography.labelButton.fontSize, 14);
      expect(AppTypography.labelButton.fontWeight, FontWeight.w600);
    });
  });
}
