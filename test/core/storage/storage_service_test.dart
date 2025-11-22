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

      test('should handle overwriting existing values', () async {
        const key = 'overwrite_key';
        await storageService.setString(key, 'original');
        await storageService.setString(key, 'updated');
        final result = await storageService.getString(key);
        expect(result, 'updated');
      });

      test('should handle very long string values', () async {
        const key = 'long_string_key';
        final longValue = 'A' * 10000;
        await storageService.setString(key, longValue);
        final result = await storageService.getString(key);
        expect(result, longValue);
      });

      test('should handle special characters in string values', () async {
        const key = 'special_chars_key';
        const value = r'Special: !@#$%^&*()_+-=[]{}|;:,.<>?';
        await storageService.setString(key, value);
        final result = await storageService.getString(key);
        expect(result, value);
      });

      test('should handle unicode characters in string values', () async {
        const key = 'unicode_key';
        const value = 'Unicode: 你好世界 🌍';
        await storageService.setString(key, value);
        final result = await storageService.getString(key);
        expect(result, value);
      });

      test('should handle negative integers', () async {
        const key = 'negative_int_key';
        const value = -42;
        await storageService.setInt(key, value);
        final result = await storageService.getInt(key);
        expect(result, value);
      });

      test('should handle large integers', () async {
        const key = 'large_int_key';
        const value = 2147483647; // Max int32
        await storageService.setInt(key, value);
        final result = await storageService.getInt(key);
        expect(result, value);
      });

      test('should handle negative doubles', () async {
        const key = 'negative_double_key';
        const value = -3.14;
        await storageService.setDouble(key, value);
        final result = await storageService.getDouble(key);
        expect(result, value);
      });

      test('should handle very large doubles', () async {
        const key = 'large_double_key';
        const value = 1.7976931348623157e+308; // Max double
        await storageService.setDouble(key, value);
        final result = await storageService.getDouble(key);
        expect(result, value);
      });

      test('should handle very small doubles', () async {
        const key = 'small_double_key';
        const value = 1e-308; // Very small double
        await storageService.setDouble(key, value);
        final result = await storageService.getDouble(key);
        expect(result, value);
      });

      test('should handle large string lists', () async {
        const key = 'large_list_key';
        final value = List.generate(1000, (index) => 'item_$index');
        await storageService.setStringList(key, value);
        final result = await storageService.getStringList(key);
        expect(result, value);
        expect(result!.length, 1000);
      });

      test('should handle string lists with empty strings', () async {
        const key = 'empty_strings_list_key';
        final value = ['item1', '', 'item2', ''];
        await storageService.setStringList(key, value);
        final result = await storageService.getStringList(key);
        expect(result, value);
      });

      test('should handle removing non-existent key', () async {
        final result = await storageService.remove('non_existent_key');
        // remove() returns true even if key doesn't exist
        expect(result, isTrue);
      });

      test('should handle clear on empty storage', () async {
        final result = await storageService.clear();
        expect(result, isTrue);
      });

      test('should handle containsKey after remove', () async {
        const key = 'remove_contains_key';
        await storageService.setString(key, 'value');
        expect(await storageService.containsKey(key), isTrue);
        await storageService.remove(key);
        expect(await storageService.containsKey(key), isFalse);
      });

      test('should handle containsKey after clear', () async {
        const key = 'clear_contains_key';
        await storageService.setString(key, 'value');
        expect(await storageService.containsKey(key), isTrue);
        await storageService.clear();
        expect(await storageService.containsKey(key), isFalse);
      });

      test('should handle lazy initialization without explicit init', () async {
        final newService = StorageService();
        // Don't call init() - should work with lazy initialization
        await newService.setString('test_key', 'test_value');
        final result = await newService.getString('test_key');
        expect(result, 'test_value');
      });

      test('should handle concurrent operations', () async {
        const key = 'concurrent_key';
        final futures = List.generate(
          10,
          (index) => storageService.setString('$key$index', 'value$index'),
        );
        await Future.wait(futures);
        for (var i = 0; i < 10; i++) {
          final result = await storageService.getString('$key$i');
          expect(result, 'value$i');
        }
      });
    });
  });
}
