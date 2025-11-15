import 'package:flutter_starter/shared/extensions/string_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StringExtensions', () {
    group('isValidEmail', () {
      test('should return true for valid email addresses', () {
        expect('test@example.com'.isValidEmail, isTrue);
        expect('user.name@example.co.uk'.isValidEmail, isTrue);
        expect('user+tag@example.com'.isValidEmail, isTrue);
        expect('user_name@example-domain.com'.isValidEmail, isTrue);
      });

      test('should return false for invalid email addresses', () {
        expect('invalid'.isValidEmail, isFalse);
        expect('@example.com'.isValidEmail, isFalse);
        expect('user@'.isValidEmail, isFalse);
        expect('user@example'.isValidEmail, isFalse);
        expect('user @example.com'.isValidEmail, isFalse);
      });
    });

    group('isValidPhone', () {
      test('should return true for valid phone numbers', () {
        expect('+1234567890'.isValidPhone, isTrue);
        expect('1234567890'.isValidPhone, isTrue);
        expect('+441234567890'.isValidPhone, isTrue);
      });

      test('should return false for invalid phone numbers', () {
        expect('abc'.isValidPhone, isFalse);
        expect('+'.isValidPhone, isFalse);
        expect('0123456789'.isValidPhone, isFalse);
        expect(''.isValidPhone, isFalse);
      });
    });

    group('capitalize', () {
      test('should capitalize first letter', () {
        expect('hello'.capitalize, 'Hello');
        expect('world'.capitalize, 'World');
        expect('HELLO'.capitalize, 'HELLO');
      });

      test('should return empty string if string is empty', () {
        expect(''.capitalize, '');
      });

      test('should handle single character', () {
        expect('a'.capitalize, 'A');
      });
    });

    group('capitalizeWords', () {
      test('should capitalize first letter of each word', () {
        expect('hello world'.capitalizeWords, 'Hello World');
        expect('hello world test'.capitalizeWords, 'Hello World Test');
      });

      test('should return empty string if string is empty', () {
        expect(''.capitalizeWords, '');
      });

      test('should handle single word', () {
        expect('hello'.capitalizeWords, 'Hello');
      });
    });

    group('removeWhitespace', () {
      test('should remove all whitespace', () {
        expect('hello world'.removeWhitespace, 'helloworld');
        expect('  hello  world  '.removeWhitespace, 'helloworld');
        expect('hello\nworld\t'.removeWhitespace, 'helloworld');
      });

      test('should return same string if no whitespace', () {
        expect('helloworld'.removeWhitespace, 'helloworld');
      });
    });

    group('isNullOrEmpty', () {
      test('should return true for empty string', () {
        expect(''.isNullOrEmpty, isTrue);
      });

      test('should return false for non-empty string', () {
        expect('hello'.isNullOrEmpty, isFalse);
      });
    });

    group('Edge Cases', () {
      test('capitalize should handle special characters', () {
        expect('123hello'.capitalize, '123hello');
        expect('!hello'.capitalize, '!hello');
      });

      test('capitalizeWords should handle multiple spaces', () {
        expect('hello   world'.capitalizeWords, 'Hello   World');
      });

      test('removeWhitespace should handle all whitespace types', () {
        expect('hello\r\nworld'.removeWhitespace, 'helloworld');
        expect('hello\fworld'.removeWhitespace, 'helloworld');
      });
    });
  });

  group('NullableStringExtensions', () {
    group('isNullOrEmpty', () {
      test('should return true for null string', () {
        const String? str = null;
        expect(str.isNullOrEmpty, isTrue);
      });

      test('should return true for empty string', () {
        expect(''.isNullOrEmpty, isTrue);
      });

      test('should return false for non-empty string', () {
        expect('hello'.isNullOrEmpty, isFalse);
      });
    });

    group('orEmpty', () {
      test('should return empty string for null', () {
        const String? str = null;
        expect(str.orEmpty, '');
      });

      test('should return string value if not null', () {
        expect('hello'.orEmpty, 'hello');
      });
    });
  });
}
