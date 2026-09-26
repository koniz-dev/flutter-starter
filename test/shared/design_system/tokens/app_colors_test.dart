import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

// The exact-value expectations below were merged in from the duplicate
// test/shared/theme/app_colors_test.dart, which imported this same subject
// from a directory that mirrored nothing in lib/. See
// koniz-dev/flutter-starter#184.
void main() {
  group('AppColors Semantic Tokens Verification', () {
    test('Primary colors are valid objects', () {
      expect(AppColors.primary, isA<Color>());
      expect(AppColors.secondary, isA<Color>());
    });

    test('Primary colors hold their documented values', () {
      expect(AppColors.primary, const Color(0xFF0069D9));
      expect(AppColors.secondary, const Color(0xFF6C757D));
    });

    test('Surface colors are valid objects', () {
      expect(AppColors.background, isA<Color>());
      expect(AppColors.surface, isA<Color>());
    });

    test('Surface colors hold their documented values', () {
      expect(AppColors.background, const Color(0xFFF8F9FA));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
    });

    test('Text colors are valid objects', () {
      expect(AppColors.textPrimary, isA<Color>());
      expect(AppColors.textSecondary, isA<Color>());
      expect(AppColors.textInverse, isA<Color>());
      expect(AppColors.textSecondaryInverse, isA<Color>());
    });

    test('Text colors hold their documented values', () {
      expect(AppColors.textPrimary, const Color(0xFF212529));
      expect(AppColors.textSecondary, const Color(0xFF5A6268));
      expect(AppColors.textInverse, const Color(0xFFFFFFFF));
      expect(AppColors.textSecondaryInverse, const Color(0xFFADB5BD));
    });

    test('Status colors are valid objects', () {
      expect(AppColors.success, isA<Color>());
      expect(AppColors.warning, isA<Color>());
      expect(AppColors.error, isA<Color>());
      expect(AppColors.info, isA<Color>());
    });

    test('Status colors hold their documented values', () {
      expect(AppColors.success, const Color(0xFF1E7E34));
      expect(AppColors.warning, const Color(0xFFFFC107));
      expect(AppColors.error, const Color(0xFFDC3545));
      expect(AppColors.info, const Color(0xFF117A8B));
    });
  });
}
