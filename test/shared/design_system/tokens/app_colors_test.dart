import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors Semantic Tokens Verification', () {
    test('Primary colors are valid objects', () {
      expect(AppColors.primary, isA<Color>());
      expect(AppColors.primaryDark, isA<Color>());
      expect(AppColors.secondary, isA<Color>());
      expect(AppColors.accent, isA<Color>());
    });

    test('Surface colors are valid objects', () {
      expect(AppColors.background, isA<Color>());
      expect(AppColors.surface, isA<Color>());
    });

    test('Text colors are valid objects', () {
      expect(AppColors.textPrimary, isA<Color>());
      expect(AppColors.textSecondary, isA<Color>());
      expect(AppColors.textInverse, isA<Color>());
    });

    test('Status colors are valid objects', () {
      expect(AppColors.success, isA<Color>());
      expect(AppColors.warning, isA<Color>());
      expect(AppColors.error, isA<Color>());
      expect(AppColors.info, isA<Color>());
    });
  });
}
