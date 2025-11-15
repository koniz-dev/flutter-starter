import 'package:flutter_starter/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    group('isValidEmail', () {
      test('should return true for valid email addresses', () {
        expect(Validators.isValidEmail('test@example.com'), isTrue);
        expect(Validators.isValidEmail('user.name@example.co.uk'), isTrue);
        expect(Validators.isValidEmail('user+tag@example.com'), isTrue);
        expect(Validators.isValidEmail('user123@example123.com'), isTrue);
      });

      test('should return false for invalid email addresses', () {
        expect(Validators.isValidEmail('invalid-email'), isFalse);
        expect(Validators.isValidEmail('@example.com'), isFalse);
        expect(Validators.isValidEmail('user@'), isFalse);
        expect(Validators.isValidEmail('user@example'), isFalse);
        expect(Validators.isValidEmail('user name@example.com'), isFalse);
        expect(Validators.isValidEmail(''), isFalse);
      });

      test('should handle edge cases', () {
        expect(Validators.isValidEmail('a@b.co'), isTrue);
        expect(Validators.isValidEmail('test@sub.domain.example.com'), isTrue);
      });
    });

    group('isValidPhone', () {
      test('should return true for valid phone numbers', () {
        expect(Validators.isValidPhone('+1234567890'), isTrue);
        expect(Validators.isValidPhone('1234567890'), isTrue);
        expect(Validators.isValidPhone('+12345678901234'), isTrue);
      });

      test('should return false for invalid phone numbers', () {
        // Note: '123' is actually valid per regex (starts with 1-9)
        expect(Validators.isValidPhone('abc'), isFalse);
        expect(Validators.isValidPhone('+'), isFalse);
        expect(Validators.isValidPhone('0123456789'), isFalse); // Starts with 0
        expect(Validators.isValidPhone(''), isFalse); // Empty
      });
    });

    group('isValidPassword', () {
      test('should return true for passwords with 8+ characters', () {
        expect(Validators.isValidPassword('password123'), isTrue);
        expect(Validators.isValidPassword('12345678'), isTrue);
        expect(Validators.isValidPassword('verylongpassword'), isTrue);
      });

      test('should return false for passwords with less than 8 characters', () {
        expect(Validators.isValidPassword('short'), isFalse);
        expect(Validators.isValidPassword('1234567'), isFalse);
        expect(Validators.isValidPassword(''), isFalse);
      });
    });

    group('isValidUrl', () {
      test('should return true for valid URLs', () {
        expect(Validators.isValidUrl('https://example.com'), isTrue);
        expect(Validators.isValidUrl('http://example.com'), isTrue);
        expect(Validators.isValidUrl('https://example.com/path'), isTrue);
        expect(Validators.isValidUrl('https://sub.example.com'), isTrue);
      });

      test('should return false for invalid URLs', () {
        expect(Validators.isValidUrl('not-a-url'), isFalse);
        expect(Validators.isValidUrl('example.com'), isFalse);
        expect(Validators.isValidUrl(''), isFalse);
      });
    });

    group('isEmpty', () {
      test('should return true for empty or null strings', () {
        expect(Validators.isEmpty(null), isTrue);
        expect(Validators.isEmpty(''), isTrue);
        expect(Validators.isEmpty('   '), isTrue);
        expect(Validators.isEmpty('\t\n'), isTrue);
      });

      test('should return false for non-empty strings', () {
        expect(Validators.isEmpty('text'), isFalse);
        expect(Validators.isEmpty('  text  '), isFalse);
      });
    });

    group('isValidUrl - Edge Cases', () {
      test('should handle URLs with ports', () {
        expect(Validators.isValidUrl('https://example.com:8080'), isTrue);
        expect(Validators.isValidUrl('http://localhost:3000'), isTrue);
      });

      test('should handle URLs with query parameters', () {
        expect(
          Validators.isValidUrl('https://example.com?key=value'),
          isTrue,
        );
        expect(
          Validators.isValidUrl('https://example.com/path?key=value'),
          isTrue,
        );
      });

      test('should handle URLs with fragments', () {
        expect(Validators.isValidUrl('https://example.com#section'), isTrue);
      });

      test('should reject URLs without scheme', () {
        expect(Validators.isValidUrl('example.com'), isFalse);
        expect(Validators.isValidUrl('//example.com'), isFalse);
      });

      test('should reject URLs without authority', () {
        expect(Validators.isValidUrl('https://'), isFalse);
        expect(Validators.isValidUrl('file:///path'), isFalse);
      });
    });

    group('isValidPassword - Edge Cases', () {
      test('should accept exactly 8 characters', () {
        expect(Validators.isValidPassword('12345678'), isTrue);
      });

      test('should reject 7 characters', () {
        expect(Validators.isValidPassword('1234567'), isFalse);
      });

      test('should handle special characters', () {
        expect(Validators.isValidPassword(r'!@#$%^&*()'), isTrue);
        expect(Validators.isValidPassword('password!'), isTrue);
      });
    });
  });
}
