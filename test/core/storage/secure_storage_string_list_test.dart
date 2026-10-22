// SecureStorageService string lists must round-trip any string.
//
// They used to be joined and split on ',', so `['a,b', 'c']` came back as
// three elements and `['']` came back empty, while the shared_preferences
// implementation of the same IStorageService contract round-tripped both.
// These tests drive the real SecureStorageService and the real
// MigrationExecutor over a mocked plugin channel.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the Keychain/Keystore holds, as raw strings.
  final backing = <String, String>{};

  setUp(() {
    backing.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          final key = args?['key'] as String? ?? '';
          switch (call.method) {
            case 'read':
              return backing[key];
            case 'containsKey':
              return backing.containsKey(key);
            case 'write':
              backing[key] = args?['value'] as String? ?? '';
              return null;
            case 'delete':
              backing.remove(key);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  group('criterion 1: any list round-trips', () {
    for (final list in <List<String>>[
      ['a,b', 'c'],
      [''],
      [],
      ['line\nbreak', 'say "hi"', r'back\slash'],
    ]) {
      test(jsonEncode(list), () async {
        final storage = SecureStorageService();

        expect(await storage.setStringList('k', list), isTrue);

        expect(await storage.getStringList('k'), list);
      });
    }
  });

  group('criterion 2: a list in the legacy comma form still reads', () {
    test("'a,b,c' reads as three elements", () async {
      backing['k'] = 'a,b,c';

      expect(await SecureStorageService().getStringList('k'), ['a', 'b', 'c']);
    });

    test("'' reads as the empty list", () async {
      backing['k'] = '';

      expect(await SecureStorageService().getStringList('k'), isEmpty);
    });

    test("a legacy value starting with '[' that is not JSON stays legacy", () {
      backing['k'] = '[urgent],home';

      return expectLater(
        SecureStorageService().getStringList('k'),
        completion(['[urgent]', 'home']),
      );
    });

    // The residual ambiguity decodeStringList
    // documents and accepts. Pinned so the doc stays true: if this ever
    // reads as legacy, the encoding changed and the doc must say how.
    test('the documented residual: legacy text that is itself a JSON array '
        'of strings reads as JSON', () async {
      backing['k'] = '["x"]';
      expect(await SecureStorageService().getStringList('k'), ['x']);

      backing['k'] = '["a","b"]';
      expect(await SecureStorageService().getStringList('k'), ['a', 'b']);
    });
  });

  group('criterion 3: MigrationV1ToV2 over secure storage', () {
    Future<void> migrate() => MigrationExecutor(
      storage: SecureStorageService(),
      loggingService: LoggingService(enableLogging: false),
      migrations: [MigrationV1ToV2()],
    ).execute();

    test('a user_tags list with a comma inside one tag survives as one '
        'element', () async {
      backing[StorageVersion.versionKey] = '1';
      await SecureStorageService().setStringList('user_tags', ['a,b', 'c']);

      await migrate();

      expect(await SecureStorageService().getStringList('user_tags'), [
        'a,b',
        'c',
      ]);
      expect(backing[StorageVersion.versionKey], '2');
    });

    test('a legacy comma-separated user_tags string still migrates', () async {
      backing[StorageVersion.versionKey] = '1';
      backing['user_tags'] = 'tag1, tag2';

      await migrate();

      expect(await SecureStorageService().getStringList('user_tags'), [
        'tag1',
        'tag2',
      ]);
    });
  });
}
