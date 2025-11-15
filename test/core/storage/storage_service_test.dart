import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.init();
    });

    group('String operations', () {
      test('should store and retrieve string', () async {
        // Arrange
        const key = 'test_string_key';
        const value = 'test_value';

        // Act
        final setResult = await storageService.setString(key, value);
        final getResult = await storageService.getString(key);

        // Assert
        expect(setResult, isTrue);
        expect(getResult, value);
      });

      test('should return null for non-existent key', () async {
        // Act
        final result = await storageService.getString('non_existent');

        // Assert
        expect(result, isNull);
      });
    });

    group('Int operations', () {
      test('should store and retrieve int', () async {
        // Arrange
        const key = 'test_int_key';
        const value = 42;

        // Act
        final setResult = await storageService.setInt(key, value);
        final getResult = await storageService.getInt(key);

        // Assert
        expect(setResult, isTrue);
        expect(getResult, value);
      });
    });

    group('Bool operations', () {
      test('should store and retrieve bool', () async {
        // Arrange
        const key = 'test_bool_key';
        const value = true;

        // Act
        final setResult = await storageService.setBool(key, value: value);
        final getResult = await storageService.getBool(key);

        // Assert
        expect(setResult, isTrue);
        expect(getResult, value);
      });
    });

    group('Double operations', () {
      test('should store and retrieve double', () async {
        // Arrange
        const key = 'test_double_key';
        const value = 3.14;

        // Act
        final setResult = await storageService.setDouble(key, value);
        final getResult = await storageService.getDouble(key);

        // Assert
        expect(setResult, isTrue);
        expect(getResult, value);
      });
    });

    group('StringList operations', () {
      test('should store and retrieve string list', () async {
        // Arrange
        const key = 'test_list_key';
        final value = ['item1', 'item2', 'item3'];

        // Act
        final setResult = await storageService.setStringList(key, value);
        final getResult = await storageService.getStringList(key);

        // Assert
        expect(setResult, isTrue);
        expect(getResult, value);
      });
    });

    group('Remove operations', () {
      test('should remove value by key', () async {
        // Arrange
        const key = 'test_remove_key';
        await storageService.setString(key, 'value');

        // Act
        final result = await storageService.remove(key);
        final getResult = await storageService.getString(key);

        // Assert
        expect(result, isTrue);
        expect(getResult, isNull);
      });
    });

    group('Clear operations', () {
      test('should clear all values', () async {
        // Arrange
        await storageService.setString('key1', 'value1');
        await storageService.setString('key2', 'value2');

        // Act
        final result = await storageService.clear();
        final getResult1 = await storageService.getString('key1');
        final getResult2 = await storageService.getString('key2');

        // Assert
        expect(result, isTrue);
        expect(getResult1, isNull);
        expect(getResult2, isNull);
      });
    });

    group('ContainsKey operations', () {
      test('should return true for existing key', () async {
        // Arrange
        const key = 'test_contains_key';
        await storageService.setString(key, 'value');

        // Act
        final result = await storageService.containsKey(key);

        // Assert
        expect(result, isTrue);
      });

      test('should return false for non-existent key', () async {
        // Act
        final result = await storageService.containsKey('non_existent');

        // Assert
        expect(result, isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty string values', () async {
        const key = 'empty_string_key';
        const value = '';

        await storageService.setString(key, value);
        final result = await storageService.getString(key);
        expect(result, value);
      });

      test('should handle zero integer', () async {
        const key = 'zero_int_key';
        const value = 0;

        await storageService.setInt(key, value);
        final result = await storageService.getInt(key);
        expect(result, value);
      });

      test('should handle false boolean', () async {
        const key = 'false_bool_key';
        const value = false;

        await storageService.setBool(key, value: value);
        final result = await storageService.getBool(key);
        expect(result, value);
      });

      test('should handle zero double', () async {
        const key = 'zero_double_key';
        const value = 0.0;

        await storageService.setDouble(key, value);
        final result = await storageService.getDouble(key);
        expect(result, value);
      });

      test('should handle empty string list', () async {
        const key = 'empty_list_key';
        const value = <String>[];

        await storageService.setStringList(key, value);
        final result = await storageService.getStringList(key);
        expect(result, value);
      });

      test('should handle null return for non-existent int', () async {
        final result = await storageService.getInt('non_existent_int');
        expect(result, isNull);
      });

      test('should handle null return for non-existent bool', () async {
        final result = await storageService.getBool('non_existent_bool');
        expect(result, isNull);
      });

      test('should handle null return for non-existent double', () async {
        final result = await storageService.getDouble('non_existent_double');
        expect(result, isNull);
      });

      test('should handle null return for non-existent list', () async {
        final result = await storageService.getStringList('non_existent_list');
        expect(result, isNull);
      });

      test('should handle multiple init calls', () async {
        await storageService.init();
        await storageService.init();
        expect(await storageService.getString('test'), isNull);
      });
    });
  });
}
