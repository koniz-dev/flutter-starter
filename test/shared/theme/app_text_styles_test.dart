import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/theme/app_text_styles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTextStyles', () {
    test('should have h1 style', () {
      expect(AppTextStyles.h1, isA<TextStyle>());
      expect(AppTextStyles.h1.fontSize, 32);
      expect(AppTextStyles.h1.fontWeight, FontWeight.bold);
    });

    test('should have h2 style', () {
      expect(AppTextStyles.h2, isA<TextStyle>());
      expect(AppTextStyles.h2.fontSize, 24);
      expect(AppTextStyles.h2.fontWeight, FontWeight.bold);
    });

    test('should have h3 style', () {
      expect(AppTextStyles.h3, isA<TextStyle>());
      expect(AppTextStyles.h3.fontSize, 20);
      expect(AppTextStyles.h3.fontWeight, FontWeight.w600);
    });

    test('should have h4 style', () {
      expect(AppTextStyles.h4, isA<TextStyle>());
      expect(AppTextStyles.h4.fontSize, 18);
      expect(AppTextStyles.h4.fontWeight, FontWeight.w600);
    });

    test('should have bodyLarge style', () {
      expect(AppTextStyles.bodyLarge, isA<TextStyle>());
      expect(AppTextStyles.bodyLarge.fontSize, 16);
      expect(AppTextStyles.bodyLarge.fontWeight, FontWeight.normal);
    });

    test('should have bodyMedium style', () {
      expect(AppTextStyles.bodyMedium, isA<TextStyle>());
      expect(AppTextStyles.bodyMedium.fontSize, 14);
      expect(AppTextStyles.bodyMedium.fontWeight, FontWeight.normal);
    });

    test('should have bodySmall style', () {
      expect(AppTextStyles.bodySmall, isA<TextStyle>());
      expect(AppTextStyles.bodySmall.fontSize, 12);
      expect(AppTextStyles.bodySmall.fontWeight, FontWeight.normal);
    });

    test('should have button style', () {
      expect(AppTextStyles.button, isA<TextStyle>());
      expect(AppTextStyles.button.fontSize, 14);
      expect(AppTextStyles.button.fontWeight, FontWeight.w600);
    });

    test('should have caption style', () {
      expect(AppTextStyles.caption, isA<TextStyle>());
      expect(AppTextStyles.caption.fontSize, 12);
      expect(AppTextStyles.caption.fontWeight, FontWeight.normal);
    });

    test('should have overline style', () {
      expect(AppTextStyles.overline, isA<TextStyle>());
      expect(AppTextStyles.overline.fontSize, 10);
      expect(AppTextStyles.overline.fontWeight, FontWeight.normal);
    });
  });
}
