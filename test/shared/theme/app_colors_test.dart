import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors tokens', () {
    test('should have primary color', () {
      expect(AppColors.primary, isA<Color>());
      expect(AppColors.primary, const Color(0xFF007BFF));
    });

    test('should have primaryDark color', () {
      expect(AppColors.primaryDark, isA<Color>());
      expect(AppColors.primaryDark, const Color(0xFF0056b3));
    });

    test('should have secondary color', () {
      expect(AppColors.secondary, isA<Color>());
      expect(AppColors.secondary, const Color(0xFF6C757D));
    });

    test('should have accent color', () {
      expect(AppColors.accent, isA<Color>());
      expect(AppColors.accent, const Color(0xFFFFC107));
    });

    test('should have surface/background colors', () {
      expect(AppColors.background, const Color(0xFFF8F9FA));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
    });

    test('should have semantic text colors', () {
      expect(AppColors.textPrimary, const Color(0xFF212529));
      expect(AppColors.textSecondary, const Color(0xFF6C757D));
      expect(AppColors.textInverse, const Color(0xFFFFFFFF));
    });

    test('should have semantic status colors', () {
      expect(AppColors.success, const Color(0xFF28A745));
      expect(AppColors.warning, const Color(0xFFFFC107));
      expect(AppColors.error, const Color(0xFFDC3545));
      expect(AppColors.info, const Color(0xFF17A2B8));
    });
  });
}
