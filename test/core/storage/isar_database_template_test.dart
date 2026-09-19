import 'package:flutter_starter/core/storage/isar_database_template.dart';
import 'package:flutter_starter/core/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IsarDatabase Template Tests', () {
    late ILocalDatabase db;

    setUp(() {
      db = IsarDatabaseTemplate();
    });

    test('should construct successfully', () {
      expect(db, isNotNull);
    });

    // `returnsNormally` is a synchronous matcher: against an async method it
    // only asserts that calling it returned a Future, which is true even of
    // an implementation that always throws (#60). Await the future instead.
    test('init completes', () async {
      await expectLater(db.init(), completes);
    });

    test('save completes and stores nothing (template is a no-op)', () async {
      await expectLater(db.save<String>('Test Object'), completes);
      expect(await db.getAll<String>(), isEmpty);
    });

    test('saveAll completes and stores nothing', () async {
      await expectLater(db.saveAll<String>(['Obj1', 'Obj2']), completes);
      expect(await db.getAll<String>(), isEmpty);
    });

    test('returns empty list for getAll', () async {
      final results = await db.getAll<String>();
      expect(results, isEmpty);
    });

    test('returns null for getById', () async {
      final result = await db.getById<String>(1);
      expect(result, isNull);
    });

    test('returns false for delete', () async {
      final result = await db.delete<String>(1);
      expect(result, isFalse);
    });

    test('clear completes', () async {
      await expectLater(db.clear<String>(), completes);
      expect(await db.getAll<String>(), isEmpty);
    });

    test('close completes', () async {
      await expectLater(db.close(), completes);
    });
  });
}
