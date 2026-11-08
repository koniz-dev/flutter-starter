import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _RejectingStore extends InMemoryStorage {
  _RejectingStore(this.rejectedKey);

  final String rejectedKey;

  @override
  Future<bool> setString(String key, String value) async =>
      key != rejectedKey && await super.setString(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) async =>
      key != rejectedKey && await super.setStringList(key, value);

  @override
  Future<bool> setInt(String key, int value) async =>
      key != rejectedKey && await super.setInt(key, value);

  @override
  Future<bool> remove(String key) async =>
      key != rejectedKey && await super.remove(key);
}

void main() {
  for (final key in [
    'username',
    'user_name',
    'theme_mode',
    'theme',
    'user_tags',
    'sync_interval_minutes',
    'old_setting_1',
  ]) {
    test('a rejected $key mutation prevents advancing the schema', () async {
      final storage = _RejectingStore(key)
        ..values.addAll({
          StorageVersion.versionKey: '1',
          'user_name': 'Alice',
          'theme': 'dark',
          'user_tags': 'one,two',
          'old_setting_1': 'legacy',
        });

      await expectLater(
        MigrationV1ToV2().execute(storage),
        throwsA(isA<MigrationException>()),
      );
      expect(storage.values[StorageVersion.versionKey], '1');
      if (key == 'username') {
        expect(storage.values['user_name'], 'Alice');
      }
      if (key == 'theme_mode') {
        expect(storage.values['theme'], 'dark');
      }

      final recovered = InMemoryStorage()..values.addAll(storage.values);
      await MigrationV1ToV2().execute(recovered);
      expect(recovered.values[StorageVersion.versionKey], '2');
      expect(recovered.values['username'], 'Alice');
      expect(recovered.values['theme_mode'], 'dark');
      expect(recovered.values['user_tags'], ['one', 'two']);
    });
  }
}
