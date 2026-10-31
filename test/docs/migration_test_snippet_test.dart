// The storage-migration guide tells adopters how to test a migration. Its
// snippet once called execute() on an empty store, which reads as version 1,
// so execute() threw MigrationException and the test it taught failed.
//
// The test below is that snippet with MigrationV2ToV3 and its keys swapped
// for the real MigrationV1ToV2 and its user_name -> username rename; the
// second test keeps the guide's text and this one in step.

import 'dart:io';

import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _guide = 'docs/guides/features/storage-migration-guide.md';
const _self = 'test/docs/migration_test_snippet_test.dart';

/// The last `test('migration renames key correctly', ...)` block in [text],
/// up to its closing `});`, with indentation and blank lines dropped. Last,
/// because this file names it once before its own copy.
String _snippet(String text) {
  final start = text.lastIndexOf(
    "test('migration renames key correctly', () async {",
  );
  expect(start, isNot(-1), reason: 'snippet not found');
  final lines = <String>[];
  for (final line in text.substring(start).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) lines.add(trimmed);
    if (trimmed == '});') break;
  }
  return lines.join('\n');
}

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test('migration renames key correctly', () async {
    final migration = MigrationV1ToV2();
    await storage.setString(
      StorageVersion.versionKey,
      '${migration.fromVersion}',
    );
    await storage.setString('user_name', 'value');

    await migration.execute(storage);

    expect(await storage.getString('username'), equals('value'));
    expect(await storage.containsKey('user_name'), isFalse);
    expect(
      await storage.getString(StorageVersion.versionKey),
      '${migration.toVersion}',
    );
  });

  test('the guide shows the test above, for its own migration', () {
    final adapted = _snippet(File(_guide).readAsStringSync())
        .replaceAll('MigrationV2ToV3', 'MigrationV1ToV2')
        .replaceAll("'old_key'", "'user_name'")
        .replaceAll("'new_key'", "'username'");

    expect(adapted, _snippet(File(_self).readAsStringSync()));
  });
}
