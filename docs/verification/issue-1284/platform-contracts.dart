import '../../lib/core/utils/json_helper.dart';
import '../../lib/core/utils/validators.dart';
const js = bool.fromEnvironment('dart.library.js_interop');
void check(String name, bool value) {
  if (!value) throw StateError('FAILED: $name');
  print('PASS $name');
}
void main() {
  print('backend=${js ? 'JavaScript' : 'VM'}');
  check('phone samples', !Validators.isValidPhone('12') && Validators.isValidPhone('0912345678') && Validators.isValidPhone('+1 555 123 4567'));
  check('URL samples', !Validators.isValidUrl('http://exa mple.com') && !Validators.isValidUrl('http://.') && !Validators.isValidUrl('javascript://alert(1)'));
  check('network schemes/IP controls', Validators.isValidUrl('ftp://example.com') && Validators.isValidUrl('wss://localhost:8080') && Validators.isValidUrl('http://[::1]'));
  check('raw port and C1 rejection', !Validators.isValidUrl('http://example.com:+80') && !Validators.isValidUrl('http://example.com:-0') && !Validators.isValidUrl('http://example.com/\u0085') && !Validators.isValidUrl('http://example.com/\u009f'));
  check('empty port and IPv6 userinfo controls', Validators.isValidUrl('http://example.com:') && Validators.isValidUrl('http://user:pass@[::1]:00080'));
  for (final value in <dynamic>[1.9, -1.9, 1e20, -1e20, double.infinity, double.nan]) {
    check('reject $value', JsonHelper.getInt({'v': value}, 'v') == null);
  }
  for (final value in <dynamic>[42, 42.0, '42', ' +00042 ', '0x2a']) {
    check('exact $value', JsonHelper.getInt({'v': value}, 'v') == 42);
  }
  const max = '9223372036854775807';
  const min = '-9223372036854775808';
  const odd = '9007199254740993';
  check('max target precision', JsonHelper.getInt({'v': max}, 'v') == (js ? null : int.parse(max)));
  check('min exact', BigInt.from(JsonHelper.getInt({'v': min}, 'v')!) == BigInt.parse(min));
  check('odd target precision', JsonHelper.getInt({'v': odd}, 'v') == (js ? null : int.parse(odd)));
  check('out of signed range', JsonHelper.getInt({'v': '9223372036854775808'}, 'v') == null);
  check('bounded leading zero parse', JsonHelper.getInt({'v': '${'0' * 100000}42'}, 'v') == 42);
}
