import '../../lib/core/utils/validators.dart';
import '../../lib/core/utils/json_helper.dart';
void main() {
  final checks = <String, bool>{
    'short phone rejection': !Validators.isValidPhone('12'),
    'local phone acceptance': Validators.isValidPhone('0912345678'),
    'formatted international phone': Validators.isValidPhone('+1 555 123 4567'),
    'spaced URL rejection': !Validators.isValidUrl('http://exa mple.com'),
    'empty-label URL rejection': !Validators.isValidUrl('http://.'),
    'script scheme rejection': !Validators.isValidUrl('javascript://alert(1)'),
    'fraction rejection': JsonHelper.getInt({'a':1.9},'a') == null,
    'overflow rejection': JsonHelper.getInt({'a':1e20},'a') == null,
    'unchanged auth email': Validators.isValidEmail('alice@example.com'),
    'unchanged auth password': Validators.isValidPassword('password'),
  };
  for(final e in checks.entries) { print('${e.value ? "PASS" : "FAIL"} ${e.key}'); }
}
