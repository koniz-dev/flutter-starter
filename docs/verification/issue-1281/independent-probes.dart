import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlakyRead extends StorageService {
  bool unreadable = true;
  @override
  Future<String?> getString(String key) async {
    if (unreadable && key == 'user_tags') throw const CacheException('read unavailable');
    return super.getString(key);
  }
}
class FlakyStamp extends StorageService {
  bool reject = true;
  @override
  Future<bool> setString(String key, String value) async {
    if (reject && key == StorageVersion.versionKey && value == '2') return false;
    return super.setString(key, value);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('independent: missing/empty/unicode strings unchanged; coded type error redacts payload', () async {
    SharedPreferences.setMockInitialValues({'empty': '', 'valid': 'Tiếng Việt 🌏', 'private': ['secret-token']});
    final store = StorageService();
    expect(await store.getString('missing'), isNull);
    expect(await store.getString('empty'), '');
    expect(await store.getString('valid'), 'Tiếng Việt 🌏');
    await expectLater(store.getString('private'), throwsA(isA<CacheException>().having((e) => e.code, 'code', invalidPreferenceTypeCode).having((e) => e.toString(), 'no payload', isNot(contains('secret-token')))));
  });
  test('independent: uncoded read failure stops migration then recovers safely', () async {
    SharedPreferences.setMockInitialValues({StorageVersion.versionKey: '1', 'user_name': 'Alice', 'user_tags': 'a,b'});
    final store = FlakyRead();
    await expectLater(MigrationV1ToV2().execute(store), throwsA(isA<CacheException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get(StorageVersion.versionKey), '1');
    expect(prefs.get('user_tags'), 'a,b');
    expect(prefs.get('username'), 'Alice');
    store.unreadable = false;
    await MigrationV1ToV2().execute(store);
    expect(prefs.get(StorageVersion.versionKey), '2');
    expect(prefs.get('user_tags'), ['a', 'b']);
    expect(prefs.get('username'), 'Alice');
  });
  test('independent: real prefs retry after failed final stamp keeps converted tags', () async {
    SharedPreferences.setMockInitialValues({StorageVersion.versionKey: '1', 'user_tags': 'a,b'});
    final store = FlakyStamp();
    await expectLater(MigrationV1ToV2().execute(store), throwsA(isA<MigrationException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get(StorageVersion.versionKey), '1');
    expect(prefs.get('user_tags'), ['a', 'b']);
    store.reject = false;
    await MigrationV1ToV2().execute(store);
    expect(prefs.get(StorageVersion.versionKey), '2');
    expect(prefs.get('user_tags'), ['a', 'b']);
  });
}
