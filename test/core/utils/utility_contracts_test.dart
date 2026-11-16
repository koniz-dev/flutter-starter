import 'package:flutter_starter/core/utils/json_helper.dart';
import 'package:flutter_starter/core/utils/validators.dart';
import 'package:flutter_starter/shared/extensions/string_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

const _usesJavaScriptNumbers = bool.fromEnvironment('dart.library.js');

void main() {
  group('utility contract phone', () {
    for (final entry in const {
      '12': false,
      '0912345678': true,
      '+1 555 123 4567': true,
      '123-456-7890': true,
      '1234567': true,
      '+123456789012345': true,
      '123456': false,
      '+1234567890123456': false,
      '+0123456789': false,
      '123abc4567': false,
      '123+4567890': false,
      '(123) 456-7890': false,
    }.entries) {
      test(entry.key, () {
        expect(Validators.isValidPhone(entry.key), entry.value);
        expect(entry.key.isValidPhone, entry.value);
      });
    }
  });

  group('utility contract URL', () {
    for (final entry in const {
      'http://exa mple.com': false,
      'http://.': false,
      'javascript://alert(1)': false,
      'javascript://example.com': false,
      'http://example..com': false,
      'http://-example.com': false,
      'http://999.999.999.999': false,
      'http://example.com:70000': false,
      r'http:\\example.com': false,
      'https://例え.テスト': false,
      'https://example.com/path with space': false,
      'http://exa%20mple.com': false,
      'https://example.com/path%20with%20space': true,
      'HTTP://example.com:65535': true,
      'ftp://example.com/file': true,
      'ws://localhost:3000': true,
      'wss://example.com': true,
      'http://127.0.0.1': true,
      'http://[::1]:8080': true,
      'https://xn--r8jz45g.xn--zckzah': true,
      'https://example.com.': true,
      'https://intranet': true,
    }.entries) {
      test(entry.key, () {
        expect(Validators.isValidUrl(entry.key), entry.value);
      });
    }
  });

  group('utility contract exact integer', () {
    for (final entry in <String, dynamic>{
      'fraction': 1.9,
      'negative fraction': -1.9,
      'overflow': 1e20,
      'negative overflow': -1e20,
      'positive overflow text': '9223372036854775808',
      'negative overflow text': '-9223372036854775809',
      'infinity': double.infinity,
      'nan': double.nan,
    }.entries) {
      test(entry.key, () {
        expect(JsonHelper.getInt({'value': entry.value}, 'value'), isNull);
      });
    }
    test('integral numbers and integer text retain their values', () {
      for (final value in <dynamic>[42, 42.0, '42', ' +00042 ', '0x2a']) {
        expect(JsonHelper.getInt({'value': value}, 'value'), 42);
      }
      expect(JsonHelper.getInt({'value': -42.0}, 'value'), -42);
      expect(JsonHelper.getInt(null, 'value'), isNull);
    });
    test('signed bounds and target representability', () {
      const max = '9223372036854775807';
      const min = '-9223372036854775808';
      const odd = '9007199254740993';
      expect(
        JsonHelper.getInt({'value': max}, 'value'),
        _usesJavaScriptNumbers ? null : int.parse(max),
      );
      expect(JsonHelper.getInt({'value': min}, 'value'), int.parse(min));
      expect(
        JsonHelper.getInt({'value': odd}, 'value'),
        _usesJavaScriptNumbers ? null : int.parse(odd),
      );
    });
    test('long leading zero text remains a bounded small integer', () {
      final value = '${'0' * 10000}42';
      expect(JsonHelper.getInt({'value': value}, 'value'), 42);
      expect(JsonHelper.getInt({'value': '9' * 10000}, 'value'), isNull);
    });
  });
}
