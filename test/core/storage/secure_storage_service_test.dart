import 'package:flutter/services.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService', () {
    late SecureStorageService secureStorageService;
    final storage = <String, String>{};

    setUp(() {
      storage.clear();
      const methodChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
        final arguments = methodCall.arguments as Map<Object?, Object?>?;
        switch (methodCall.method) {
          case 'read':
            final key = arguments?['key'] as String? ?? '';
            return storage[key];
          case 'write':
            final key = arguments?['key'] as String? ?? '';
            final value = arguments?['value'] as String? ?? '';
            storage[key] = value;
            return null;
          case 'delete':
            final key = arguments?['key'] as String? ?? '';
            storage.remove(key);
            return null;
          case 'deleteAll':
            storage.clear();
            return null;
          default:
            return null;
        }
      });
      
      secureStorageService = SecureStorageService();
    });

    tearDown(() async {
      storage.clear();
      const methodChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });


    group('String Operations', () {
      test('should store and retrieve string value', () async {
        const key = 'test_string_key';
        const value = 'test_string_value';

        final setResult = await secureStorageService.setString(key, value);
        expect(setResult, isTrue);

        final retrievedValue = await secureStorageService.getString(key);
        expect(retrievedValue, value);
      });

      test('should return null for non-existent key', () async {
        const key = 'non_existent_key';

        final value = await secureStorageService.getString(key);
        expect(value, isNull);
      });

      test('should overwrite existing value', () async {
        const key = 'test_key';
        const value1 = 'value1';
        const value2 = 'value2';

        await secureStorageService.setString(key, value1);
        await secureStorageService.setString(key, value2);

        final retrievedValue = await secureStorageService.getString(key);
        expect(retrievedValue, value2);
      });
    });

    group('Integer Operations', () {
      test('should store and retrieve integer value', () async {
        const key = 'test_int_key';
        const value = 42;

        final setResult = await secureStorageService.setInt(key, value);
        expect(setResult, isTrue);

        final retrievedValue = await secureStorageService.getInt(key);
        expect(retrievedValue, value);
      });

      test('should return null for non-existent integer key', () async {
        const key = 'non_existent_int_key';

        final value = await secureStorageService.getInt(key);
        expect(value, isNull);
      });

      test('should handle negative integers', () async {
        const key = 'negative_int_key';
        const value = -42;

        await secureStorageService.setInt(key, value);
        final retrievedValue = await secureStorageService.getInt(key);
        expect(retrievedValue, value);
      });
    });

    group('Boolean Operations', () {
      test('should store and retrieve boolean value (true)', () async {
        const key = 'test_bool_key';
        const value = true;

        final setResult = await secureStorageService.setBool(key, value: value);
        expect(setResult, isTrue);

        final retrievedValue = await secureStorageService.getBool(key);
        expect(retrievedValue, value);
      });

      test('should store and retrieve boolean value (false)', () async {
        const key = 'test_bool_key_false';
        const value = false;

        await secureStorageService.setBool(key, value: value);
        final retrievedValue = await secureStorageService.getBool(key);
        expect(retrievedValue, value);
      });

      test('should return null for non-existent boolean key', () async {
        const key = 'non_existent_bool_key';

        final value = await secureStorageService.getBool(key);
        expect(value, isNull);
      });
    });

    group('Double Operations', () {
      test('should store and retrieve double value', () async {
        const key = 'test_double_key';
        const value = 3.14159;

        final setResult = await secureStorageService.setDouble(key, value);
        expect(setResult, isTrue);

        final retrievedValue = await secureStorageService.getDouble(key);
        expect(retrievedValue, closeTo(value, 0.00001));
      });

      test('should return null for non-existent double key', () async {
        const key = 'non_existent_double_key';

        final value = await secureStorageService.getDouble(key);
        expect(value, isNull);
      });
    });

    group('String List Operations', () {
      test('should store and retrieve string list', () async {
        const key = 'test_list_key';
        const value = ['item1', 'item2', 'item3'];

        final setResult = await secureStorageService.setStringList(key, value);
        expect(setResult, isTrue);

        final retrievedValue = await secureStorageService.getStringList(key);
        expect(retrievedValue, value);
      });

      test('should return null for non-existent list key', () async {
        const key = 'non_existent_list_key';

        final value = await secureStorageService.getStringList(key);
        expect(value, isNull);
      });

      test('should handle empty list', () async {
        const key = 'empty_list_key';
        const value = <String>[];

        await secureStorageService.setStringList(key, value);
        final retrievedValue = await secureStorageService.getStringList(key);
        expect(retrievedValue, isEmpty);
      });
    });

    group('Remove Operations', () {
      test('should remove existing key', () async {
        const key = 'key_to_remove';
        const value = 'value';

        await secureStorageService.setString(key, value);
        final removeResult = await secureStorageService.remove(key);
        expect(removeResult, isTrue);

        final retrievedValue = await secureStorageService.getString(key);
        expect(retrievedValue, isNull);
      });

      test('should return true when removing non-existent key', () async {
        const key = 'non_existent_key';

        final removeResult = await secureStorageService.remove(key);
        expect(removeResult, isTrue);
      });
    });

    group('Clear Operations', () {
      test('should clear all stored values', () async {
        await secureStorageService.setString('key1', 'value1');
        await secureStorageService.setString('key2', 'value2');
        await secureStorageService.setInt('key3', 42);

        final clearResult = await secureStorageService.clear();
        expect(clearResult, isTrue);

        expect(await secureStorageService.getString('key1'), isNull);
        expect(await secureStorageService.getString('key2'), isNull);
        expect(await secureStorageService.getInt('key3'), isNull);
      });
    });

    group('Contains Key Operations', () {
      test('should return true for existing key', () async {
        const key = 'existing_key';
        const value = 'value';

        await secureStorageService.setString(key, value);
        final contains = await secureStorageService.containsKey(key);
        expect(contains, isTrue);
      });

      test('should return false for non-existent key', () async {
        const key = 'non_existent_key';

        final contains = await secureStorageService.containsKey(key);
        expect(contains, isFalse);
      });

      test('should return false after removing key', () async {
        const key = 'key_to_check';
        const value = 'value';

        await secureStorageService.setString(key, value);
        await secureStorageService.remove(key);

        final contains = await secureStorageService.containsKey(key);
        expect(contains, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle invalid integer parsing gracefully', () async {
        const key = 'invalid_int_key';
        const invalidValue = 'not_a_number';

        // Store as string that can't be parsed as int
        await secureStorageService.setString(key, invalidValue);
        final retrievedValue = await secureStorageService.getInt(key);
        expect(retrievedValue, isNull);
      });

      test('should handle invalid double parsing gracefully', () async {
        const key = 'invalid_double_key';
        const invalidValue = 'not_a_number';

        await secureStorageService.setString(key, invalidValue);
        final retrievedValue = await secureStorageService.getDouble(key);
        expect(retrievedValue, isNull);
      });
    });
  });
}
