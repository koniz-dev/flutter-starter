import 'package:flutter_starter/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    group('isValidEmail', () {
      // Table-driven. The standard validated against is documented on the
      // Validators class: an RFC 5322 `dot-atom` local part, widened for
      // RFC 6531 (SMTPUTF8), at a domain of two or more RFC 1035 LDH
      // labels, within the RFC 5321 size limits.

      // Every entry here is a legitimate address. Rejecting one of these is
      // a worse bug than accepting a malformed address, so the awkward but
      // legal cases are in the table on purpose.
      const validAddresses = <String, String>{
        'test@example.com': 'the ordinary case',
        'user.name@example.co.uk': 'dots inside the local part, two-level TLD',
        'user+tag@example.com': 'plus addressing',
        'a+b@example.co.uk': 'plus addressing, two-level TLD',
        'first.last@sub.domain.example.com': 'deep subdomain',
        'a@b.co': 'shortest plausible address',
        'user-name@ex-ample.com': 'hyphens inside labels',
        '_user@example.com': 'leading underscore is atext, unlike a dot',
        'user_@example.com': 'trailing underscore is atext, unlike a dot',
        '123user@example.com': 'digit-leading local part',
        'user@123example.com': 'digit-leading domain label',
        r"!#$%&'*+-/=?^_`{|}~@example.com":
            'every printable ASCII atext character',
        'user@example.xn--p1ai': 'punycode TLD - digits and hyphens inside',
        'jos\u00e9@example.com': 'non-ASCII local part, valid under SMTPUTF8',
        '\u7528\u6237@\u4f8b\u5b50.\u6d4b\u8bd5':
            'fully internationalised address (RFC 6531)',
      };

      // Every entry here is malformed or deliberately out of scope.
      const invalidAddresses = <String, String>{
        'user@example..com': 'empty DNS label',
        'user@-example.com': 'label starts with a hyphen',
        'user@example-.com': 'label ends with a hyphen',
        '.user@example.com': 'leading dot in the local part',
        'user.@example.com': 'trailing dot in the local part',
        'user..name@example.com': 'consecutive dots in the local part',
        'user@@example.com': 'two at-signs',
        'user@example': 'single-label domain',
        'user@.com': 'empty first label',
        'user@example.c': 'one-character TLD',
        'user@example.123': 'all-digit TLD',
        'user@example.com.': 'trailing root dot',
        '': 'empty string',
        'user': 'no at-sign',
        'invalid-email': 'no at-sign',
        'user@': 'empty domain',
        '@example.com': 'empty local part',
        'user name@example.com': 'space in the local part',
        'user@exam ple.com': 'space in the domain',
        ' user@example.com': 'leading space',
        'user@example.com ': 'trailing space',
        'user@example .com': 'space before the dot',
        'user@localhost': 'deliberately rejected: single-label domain',
        '"john doe"@example.com':
            'deliberately rejected: quoted-string local part',
        'user@[192.168.0.1]': 'deliberately rejected: domain literal',
        'user(comment)@example.com':
            'deliberately rejected: comment in the local part',
      };

      validAddresses.forEach((address, why) {
        test('accepts <$address> - $why', () {
          expect(Validators.isValidEmail(address), isTrue);
        });
      });

      invalidAddresses.forEach((address, why) {
        test('rejects <$address> - $why', () {
          expect(Validators.isValidEmail(address), isFalse);
        });
      });

      test('rejects newline injection at either end', () {
        expect(Validators.isValidEmail('user@example.com\n'), isFalse);
        expect(Validators.isValidEmail('\nuser@example.com'), isFalse);
        expect(
          Validators.isValidEmail('user@example.com\nbcc:x@y.com'),
          isFalse,
        );
      });

      test('enforces the RFC 5321 local part limit of 64 octets', () {
        expect(Validators.isValidEmail('${'a' * 64}@example.com'), isTrue);
        expect(Validators.isValidEmail('${'a' * 65}@example.com'), isFalse);
      });

      test('enforces the RFC 1035 label limit of 63 octets', () {
        expect(Validators.isValidEmail('u@${'b' * 63}.com'), isTrue);
        expect(Validators.isValidEmail('u@${'b' * 64}.com'), isFalse);
      });

      test('enforces the overall 254-octet limit', () {
        final tooLong = '${'a' * 64}@${'b' * 63}.${'c' * 63}.${'d' * 60}.com';
        expect(tooLong.length, greaterThan(254));
        expect(Validators.isValidEmail(tooLong), isFalse);
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

      test('should handle phone numbers with country codes', () {
        expect(Validators.isValidPhone('+12345678901'), isTrue);
        expect(Validators.isValidPhone('+9876543210'), isTrue);
        expect(Validators.isValidPhone('+112345678901234'), isTrue);
      });

      test('should handle phone numbers without country code', () {
        expect(Validators.isValidPhone('1234567890'), isTrue);
        expect(Validators.isValidPhone('9876543210'), isTrue);
        expect(Validators.isValidPhone('12345678901234'), isTrue);
      });

      test('should reject phone numbers starting with zero', () {
        expect(Validators.isValidPhone('0123456789'), isFalse);
        expect(Validators.isValidPhone('+0123456789'), isFalse);
      });

      test('should reject phone numbers with letters', () {
        expect(Validators.isValidPhone('123abc456'), isFalse);
        expect(Validators.isValidPhone('abc123'), isFalse);
        expect(Validators.isValidPhone('+123abc'), isFalse);
      });

      test('should reject phone numbers with special characters', () {
        expect(Validators.isValidPhone('123-456-7890'), isFalse);
        expect(Validators.isValidPhone('(123) 456-7890'), isFalse);
        expect(Validators.isValidPhone('123.456.7890'), isFalse);
        expect(Validators.isValidPhone('123 456 7890'), isFalse);
      });

      test('should handle minimum length phone numbers', () {
        // Regex requires: [1-9] + at least 1 digit = minimum 2 digits
        expect(Validators.isValidPhone('12'), isTrue);
        expect(Validators.isValidPhone('+12'), isTrue);
        expect(Validators.isValidPhone('19'), isTrue);
      });

      test('should handle maximum length phone numbers', () {
        // Regex allows: [1-9] + up to 14 digits = maximum 15 digits total
        expect(Validators.isValidPhone('12345678901234'), isTrue); // 15 digits
        expect(
          Validators.isValidPhone('+12345678901234'),
          isTrue, // 15 digits with +
        );
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

      test('should handle URLs with different schemes', () {
        expect(Validators.isValidUrl('https://example.com'), isTrue);
        expect(Validators.isValidUrl('http://example.com'), isTrue);
        expect(Validators.isValidUrl('ftp://example.com'), isTrue);
        expect(Validators.isValidUrl('ws://example.com'), isTrue);
        expect(Validators.isValidUrl('wss://example.com'), isTrue);
      });

      test('should reject URLs without scheme', () {
        expect(Validators.isValidUrl('example.com'), isFalse);
        expect(Validators.isValidUrl('//example.com'), isFalse);
        expect(Validators.isValidUrl('www.example.com'), isFalse);
      });

      test('should reject URLs without authority', () {
        expect(Validators.isValidUrl('https://'), isFalse);
        expect(Validators.isValidUrl('http://'), isFalse);
      });

      test('should reject URLs with empty host', () {
        expect(Validators.isValidUrl('file:///path'), isFalse);
        expect(Validators.isValidUrl('https:///path'), isFalse);
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

      test('should handle strings with only whitespace', () {
        expect(Validators.isEmpty(' '), isTrue);
        expect(Validators.isEmpty('\t'), isTrue);
        expect(Validators.isEmpty('\n'), isTrue);
        expect(Validators.isEmpty('\r'), isTrue);
        expect(Validators.isEmpty(' \t\n\r '), isTrue);
      });

      test('should handle strings with mixed whitespace and content', () {
        expect(Validators.isEmpty('  text  '), isFalse);
        expect(Validators.isEmpty('\ttext\n'), isFalse);
        expect(Validators.isEmpty(' text '), isFalse);
      });

      test('should handle unicode whitespace', () {
        expect(Validators.isEmpty('\u00A0'), isTrue); // Non-breaking space
        expect(Validators.isEmpty('\u2000'), isTrue); // En quad
        expect(Validators.isEmpty('\u2001'), isTrue); // Em quad
      });

      test('should handle empty strings with special characters', () {
        expect(Validators.isEmpty(''), isTrue);
        expect(Validators.isEmpty('   '), isTrue);
      });
    });

    group('isValidUrl - Edge Cases', () {
      test('should handle URLs with ports', () {
        expect(Validators.isValidUrl('https://example.com:8080'), isTrue);
        expect(Validators.isValidUrl('http://localhost:3000'), isTrue);
      });

      test('should handle URLs with query parameters', () {
        expect(Validators.isValidUrl('https://example.com?key=value'), isTrue);
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
        // file:///path has an empty host, so it should be rejected
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

      test('should handle unicode characters', () {
        expect(Validators.isValidPassword('passwordñ'), isTrue);
        expect(Validators.isValidPassword('пароль123'), isTrue);
        expect(Validators.isValidPassword('密码123456'), isTrue);
      });

      test('should handle very long passwords', () {
        final longPassword = 'a' * 100;
        expect(Validators.isValidPassword(longPassword), isTrue);
      });

      test('should handle passwords with spaces', () {
        expect(Validators.isValidPassword('pass word'), isTrue);
        expect(Validators.isValidPassword('  password  '), isTrue);
      });

      test('should handle passwords with only numbers', () {
        expect(Validators.isValidPassword('12345678'), isTrue);
        expect(Validators.isValidPassword('1234567890123456'), isTrue);
      });

      test('should handle passwords with only letters', () {
        expect(Validators.isValidPassword('password'), isTrue);
        expect(Validators.isValidPassword('PASSWORD'), isTrue);
        expect(Validators.isValidPassword('Password'), isTrue);
      });
    });
    group('isStrongPassword', () {
      test('should return true for passwords meeting all criteria', () {
        expect(Validators.isStrongPassword('Password123!'), isTrue);
        expect(Validators.isStrongPassword('ABCdef12@'), isTrue);
      });

      test('should return false if missing uppercase', () {
        expect(Validators.isStrongPassword('password123!'), isFalse);
      });

      test('should return false if missing lowercase', () {
        expect(Validators.isStrongPassword('PASSWORD123!'), isFalse);
      });

      test('should return false if missing digit', () {
        expect(Validators.isStrongPassword('Password!@#'), isFalse);
      });

      test('should return false if missing special character', () {
        expect(Validators.isStrongPassword('Password123'), isFalse);
      });

      test('should return false if less than 8 characters', () {
        expect(Validators.isStrongPassword('Pas12!'), isFalse);
      });

      test('accepts every non-alphanumeric as the special character', () {
        // The old hand-written class was [!@#\$%^&*(),.?":{}|<>], so each of
        // these was rejected while the doc comment promised otherwise.
        for (final special in [
          '_',
          '-',
          '+',
          '=',
          '[',
          ']',
          ';',
          '/',
          r'\',
          '~',
          ' ',
          "'",
        ]) {
          expect(
            Validators.isStrongPassword('Passw0rd$special'),
            isTrue,
            reason: 'special character <$special> should satisfy the rule',
          );
        }
      });

      test('doc comment and behaviour agree: no special char means false', () {
        // `Password1` satisfies length, upper, lower and digit. The doc now
        // states the fourth requirement, so this result is documented rather
        // than surprising.
        expect(Validators.isStrongPassword('Password1'), isFalse);
      });
    });

    group('isNumeric', () {
      test('should return true for purely numeric strings', () {
        expect(Validators.isNumeric('12345'), isTrue);
        expect(Validators.isNumeric('-123'), isTrue);
      });

      test('should return false for alphanumeric strings', () {
        expect(Validators.isNumeric('123a'), isFalse);
        expect(Validators.isNumeric('a123'), isFalse);
      });

      test('should return false for empty string', () {
        expect(Validators.isNumeric(''), isFalse);
      });
    });

    group('isAlphaNumeric', () {
      test('should return true for alphanumeric strings', () {
        expect(Validators.isAlphaNumeric('abc123'), isTrue);
        expect(Validators.isAlphaNumeric('ABC123'), isTrue);
        expect(Validators.isAlphaNumeric('12345'), isTrue);
        expect(Validators.isAlphaNumeric('abcde'), isTrue);
      });

      test('should return false for strings with special characters', () {
        expect(Validators.isAlphaNumeric('abc_123'), isFalse);
        expect(Validators.isAlphaNumeric('abc-123'), isFalse);
        expect(Validators.isAlphaNumeric('abc 123'), isFalse);
      });
    });
  });
}
