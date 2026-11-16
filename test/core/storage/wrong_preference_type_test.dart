import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnreadableLegacyStorage extends StorageService {
  @override
  Future<String?> getString(String key) async {
    if (key == 'user_tags') {
      throw const CacheException('Read unavailable', code: 'STORE_READ_FAILED');
    }
    return await super.getString(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final value in <Object>[
    42,
    true,
    1.5,
    <String>['preserve me'],
  ]) {
    test('wrong preference type: ${value.runtimeType} reports storage failure '
        'without deleting the value', () async {
      SharedPreferences.setMockInitialValues({'value': value});
      final storage = StorageService();
      await expectLater(
        storage.getString('value'),
        throwsA(isA<CacheException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('value'), value);
      expect(await storage.setString('value', 'repaired'), isTrue);
      expect(await storage.getString('value'), 'repaired');
    });
  }

  test(
    'migration preserves schema and legacy data on other read failures',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageVersion.versionKey: '1',
        'user_tags': 'original,tags',
      });
      final storage = _UnreadableLegacyStorage();
      await expectLater(
        MigrationV1ToV2().execute(storage),
        throwsA(
          isA<CacheException>().having(
            (error) => error.code,
            'code',
            'STORE_READ_FAILED',
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(StorageVersion.versionKey), '1');
      expect(prefs.get('user_tags'), 'original,tags');
    },
  );
}
