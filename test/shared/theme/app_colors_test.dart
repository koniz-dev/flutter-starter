import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('should have primary color', () {
      expect(AppColors.primary, isA<Color>());
      expect(AppColors.primary, const Color(0xFF6200EE));
    });

    test('should have primaryVariant color', () {
      expect(AppColors.primaryVariant, isA<Color>());
      expect(AppColors.primaryVariant, const Color(0xFF3700B3));
    });

    test('should have secondary color', () {
      expect(AppColors.secondary, isA<Color>());
      expect(AppColors.secondary, const Color(0xFF03DAC6));
    });

    test('should have secondaryVariant color', () {
      expect(AppColors.secondaryVariant, isA<Color>());
      expect(AppColors.secondaryVariant, const Color(0xFF018786));
    });

    test('should have background color', () {
      expect(AppColors.background, isA<Color>());
      expect(AppColors.background, const Color(0xFFF5F5F5));
    });

    test('should have surface color', () {
      expect(AppColors.surface, isA<Color>());
      expect(AppColors.surface, const Color(0xFFFFFFFF));
    });

    test('should have textPrimary color', () {
      expect(AppColors.textPrimary, isA<Color>());
      expect(AppColors.textPrimary, const Color(0xFF212121));
    });

    test('should have textSecondary color', () {
      expect(AppColors.textSecondary, isA<Color>());
      expect(AppColors.textSecondary, const Color(0xFF757575));
    });

    test('should have textOnPrimary color', () {
      expect(AppColors.textOnPrimary, isA<Color>());
      expect(AppColors.textOnPrimary, const Color(0xFFFFFFFF));
    });

    test('should have error color', () {
      expect(AppColors.error, isA<Color>());
      expect(AppColors.error, const Color(0xFFB00020));
    });

    test('should have errorLight color', () {
      expect(AppColors.errorLight, isA<Color>());
      expect(AppColors.errorLight, const Color(0xFFEF5350));
    });

    test('should have success color', () {
      expect(AppColors.success, isA<Color>());
      expect(AppColors.success, const Color(0xFF4CAF50));
    });

    test('should have successLight color', () {
      expect(AppColors.successLight, isA<Color>());
      expect(AppColors.successLight, const Color(0xFF81C784));
    });

    test('should have warning color', () {
      expect(AppColors.warning, isA<Color>());
      expect(AppColors.warning, const Color(0xFFFF9800));
    });

    test('should have warningLight color', () {
      expect(AppColors.warningLight, isA<Color>());
      expect(AppColors.warningLight, const Color(0xFFFFB74D));
    });

    test('should have border color', () {
      expect(AppColors.border, isA<Color>());
      expect(AppColors.border, const Color(0xFFE0E0E0));
    });

    test('should have borderLight color', () {
      expect(AppColors.borderLight, isA<Color>());
      expect(AppColors.borderLight, const Color(0xFFF5F5F5));
    });
  });
}
