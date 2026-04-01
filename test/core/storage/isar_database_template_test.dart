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

    test('calls init gracefully', () async {
      expect(() => db.init(), returnsNormally);
    });

    test('calls save gracefully', () async {
      expect(() => db.save<String>('Test Object'), returnsNormally);
    });

    test('calls saveAll gracefully', () async {
      expect(() => db.saveAll<String>(['Obj1', 'Obj2']), returnsNormally);
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

    test('calls clear gracefully', () async {
      expect(() => db.clear<String>(), returnsNormally);
    });

    test('calls close gracefully', () async {
      expect(() => db.close(), returnsNormally);
    });
  });
}
