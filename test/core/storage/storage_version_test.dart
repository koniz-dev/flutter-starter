import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageVersion', () {
    test('current version is expected', () {
      expect(StorageVersion.current, equals(2));
    });

    test('initial version is expected', () {
      expect(StorageVersion.initial, equals(1));
    });

    test('versionKey is expected', () {
      expect(StorageVersion.versionKey, equals('_storage_version'));
    });

    test('migrationStatusKey is expected', () {
      expect(StorageVersion.migrationStatusKey, equals('_migration_status'));
    });

    test('current version is greater than initial', () {
      expect(StorageVersion.current, greaterThan(StorageVersion.initial));
    });
  });
}
