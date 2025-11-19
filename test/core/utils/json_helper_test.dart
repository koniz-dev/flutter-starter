import 'package:flutter_starter/core/utils/json_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonHelper', () {
    group('decode', () {
      test('should decode valid JSON string', () {
        const json = '{"key": "value"}';
        final result = JsonHelper.decode(json);
        expect(result, isA<Map<String, dynamic>>());
        expect((result as Map)['key'], 'value');
      });

      test('should decode JSON array', () {
        const json = '[1, 2, 3]';
        final result = JsonHelper.decode(json);
        expect(result, isA<List<dynamic>>());
        expect(result, [1, 2, 3]);
      });

      test('should return null for invalid JSON', () {
        expect(JsonHelper.decode('invalid json'), isNull);
        expect(JsonHelper.decode('{invalid}'), isNull);
      });

      test('should return null for null or empty string', () {
        expect(JsonHelper.decode(null), isNull);
        expect(JsonHelper.decode(''), isNull);
      });
    });

    group('decodeMap', () {
      test('should decode valid JSON map', () {
        const json = '{"key": "value", "number": 123}';
        final result = JsonHelper.decodeMap(json);
        expect(result, isNotNull);
        expect(result!['key'], 'value');
        expect(result['number'], 123);
      });

      test('should return null for non-map JSON', () {
        expect(JsonHelper.decodeMap('[1, 2, 3]'), isNull);
        expect(JsonHelper.decodeMap('"string"'), isNull);
      });

      test('should return null for invalid JSON', () {
        expect(JsonHelper.decodeMap('invalid'), isNull);
      });
    });

    group('decodeList', () {
      test('should decode valid JSON list', () {
        const json = '["a", "b", "c"]';
        final result = JsonHelper.decodeList(json);
        expect(result, isNotNull);
        expect(result, ['a', 'b', 'c']);
      });

      test('should return null for non-list JSON', () {
        expect(JsonHelper.decodeList('{"key": "value"}'), isNull);
      });
    });

    group('encode', () {
      test('should encode map to JSON string', () {
        final map = {'key': 'value', 'number': 123};
        final result = JsonHelper.encode(map);
        expect(result, isNotNull);
        expect(result, contains('"key"'));
        expect(result, contains('"value"'));
      });

      test('should encode list to JSON string', () {
        final list = [1, 2, 3];
        final result = JsonHelper.encode(list);
        expect(result, isNotNull);
        expect(result, '[1,2,3]');
      });

      test('should return null for unencodable objects', () {
        // Objects with functions can't be encoded
        final object = Object();
        // This should handle gracefully and return null
        expect(JsonHelper.encode(object), isNull);
      });
    });

    group('getValue', () {
      test('should get value by key', () {
        final map = {'key': 'value', 'number': 123};
        expect(JsonHelper.getValue<String>(map, 'key'), 'value');
        expect(JsonHelper.getValue<int>(map, 'number'), 123);
      });

      test('should return null for missing key', () {
        final map = {'key': 'value'};
        expect(JsonHelper.getValue<String>(map, 'missing'), isNull);
      });

      test('should return null for null map', () {
        expect(JsonHelper.getValue<String>(null, 'key'), isNull);
      });

      test('should return null for wrong type', () {
        final map = {'key': 'value'};
        expect(JsonHelper.getValue<int>(map, 'key'), isNull);
      });
    });

    group('getString', () {
      test('should get string value', () {
        final map = {'key': 'value'};
        expect(JsonHelper.getString(map, 'key'), 'value');
      });

      test('should return null for non-string value', () {
        final map = {'key': 123};
        expect(JsonHelper.getString(map, 'key'), isNull);
      });
    });

    group('getInt', () {
      test('should get int value', () {
        final map = {'key': 123};
        expect(JsonHelper.getInt(map, 'key'), 123);
      });

      test('should parse string number to int', () {
        final map = {'key': '123'};
        expect(JsonHelper.getInt(map, 'key'), 123);
      });

      test('should parse num to int', () {
        final map = {'key': 123.0};
        expect(JsonHelper.getInt(map, 'key'), 123);
      });

      test('should return null for invalid value', () {
        final map = {'key': 'invalid'};
        expect(JsonHelper.getInt(map, 'key'), isNull);
      });
    });

    group('getDouble', () {
      test('should get double value', () {
        final map = {'key': 123.45};
        expect(JsonHelper.getDouble(map, 'key'), 123.45);
      });

      test('should parse string number to double', () {
        final map = {'key': '123.45'};
        expect(JsonHelper.getDouble(map, 'key'), 123.45);
      });

      test('should parse int to double', () {
        final map = {'key': 123};
        expect(JsonHelper.getDouble(map, 'key'), 123.0);
      });
    });

    group('getBool', () {
      test('should get bool value', () {
        final map = {'key': true};
        expect(JsonHelper.getBool(map, 'key'), isTrue);
      });

      test('should return null for non-bool value', () {
        final map = {'key': 'true'};
        expect(JsonHelper.getBool(map, 'key'), isNull);
      });
    });

    group('isValidJson', () {
      test('should return true for valid JSON', () {
        expect(JsonHelper.isValidJson('{"key": "value"}'), isTrue);
        expect(JsonHelper.isValidJson('[1, 2, 3]'), isTrue);
      });

      test('should return false for invalid JSON', () {
        expect(JsonHelper.isValidJson('invalid'), isFalse);
        expect(JsonHelper.isValidJson(null), isFalse);
        expect(JsonHelper.isValidJson(''), isFalse);
      });
    });

    group('merge', () {
      test('should merge two maps', () {
        final map1 = {'a': 1, 'b': 2};
        final map2 = {'c': 3, 'd': 4};
        final result = JsonHelper.merge(map1, map2);
        expect(result, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
      });

      test('should handle null maps', () {
        final map1 = {'a': 1};
        expect(JsonHelper.merge(map1, null), {'a': 1});
        expect(JsonHelper.merge(null, map1), {'a': 1});
        expect(JsonHelper.merge(null, null), <String, dynamic>{});
      });

      test('should override values from second map', () {
        final map1 = {'a': 1, 'b': 2};
        final map2 = {'b': 3};
        final result = JsonHelper.merge(map1, map2);
        expect(result['b'], 3);
      });
    });

    group('encodePretty', () {
      test('should encode map with indentation', () {
        final map = {'key': 'value', 'number': 123};
        final result = JsonHelper.encodePretty(map);
        expect(result, isNotNull);
        expect(result, contains('  ')); // Should have indentation
        expect(result, contains('"key"'));
      });

      test('should return null for unencodable objects', () {
        // Create an object with a function which can't be encoded
        final object = {'func': () {}};
        expect(JsonHelper.encodePretty(object), isNull);
      });

      test('should handle encodePretty with Exception during encoding', () {
        // Create an object that causes exception during encoding
        final object = Object();
        // This might cause an exception in some cases
        final result = JsonHelper.encodePretty(object);
        // Should return null if exception occurs (Object() cannot be encoded)
        expect(result, isNull);
      });
    });

    group('getMap', () {
      test('should get nested map', () {
        final map = {
          'nested': {'key': 'value'},
        };
        final result = JsonHelper.getMap(map, 'nested');
        expect(result, isNotNull);
        expect(result!['key'], 'value');
      });

      test('should return null for non-map value', () {
        final map = {'key': 'value'};
        expect(JsonHelper.getMap(map, 'key'), isNull);
      });

      test('should return null for missing key', () {
        final map = {'other': 'value'};
        expect(JsonHelper.getMap(map, 'missing'), isNull);
      });
    });

    group('getList', () {
      test('should get list value', () {
        final map = {
          'items': [1, 2, 3],
        };
        final result = JsonHelper.getList(map, 'items');
        expect(result, isNotNull);
        expect(result, [1, 2, 3]);
      });

      test('should return null for non-list value', () {
        final map = {'key': 'value'};
        expect(JsonHelper.getList(map, 'key'), isNull);
      });
    });

    group('getListOf', () {
      test('should get list of strings', () {
        final map = {
          'items': ['a', 'b', 'c'],
        };
        final result = JsonHelper.getListOf<String>(
          map,
          'items',
          (item) => item.toString(),
        );
        expect(result, isNotNull);
        expect(result, ['a', 'b', 'c']);
      });

      test('should convert list items', () {
        final map = {
          'numbers': [1, 2, 3],
        };
        final result = JsonHelper.getListOf<String>(
          map,
          'numbers',
          (item) => item.toString(),
        );
        expect(result, ['1', '2', '3']);
      });

      test('should return null for missing key', () {
        final map = {'other': 'value'};
        final result = JsonHelper.getListOf<String>(
          map,
          'missing',
          (item) => item.toString(),
        );
        expect(result, isNull);
      });

      test('should return null when conversion fails', () {
        final map = {
          'items': ['a', 'b', 'c'],
        };
        final result = JsonHelper.getListOf<int>(
          map,
          'items',
          (item) {
            if (item is int) return item;
            throw Exception('Cannot convert');
          },
        );
        expect(result, isNull);
      });
    });

    group('deepMerge', () {
      test('should deep merge nested maps', () {
        final map1 = {
          'a': 1,
          'nested': {'x': 10, 'y': 20},
        };
        final map2 = {
          'b': 2,
          'nested': {'y': 30, 'z': 40},
        };
        final result = JsonHelper.deepMerge(map1, map2);
        expect(result['a'], 1);
        expect(result['b'], 2);
        expect(result['nested'], isA<Map<String, dynamic>>());
        final nested = result['nested'] as Map<String, dynamic>;
        expect(nested['x'], 10);
        expect(nested['y'], 30); // Overridden
        expect(nested['z'], 40);
      });

      test('should handle null maps', () {
        final map1 = {'a': 1};
        expect(JsonHelper.deepMerge(map1, null), {'a': 1});
        expect(JsonHelper.deepMerge(null, map1), {'a': 1});
        expect(JsonHelper.deepMerge(null, null), <String, dynamic>{});
      });

      test('should override non-map values', () {
        final map1 = {'key': 'old'};
        final map2 = {'key': 'new'};
        final result = JsonHelper.deepMerge(map1, map2);
        expect(result['key'], 'new');
      });
    });

    group('removeNulls', () {
      test('should remove null values', () {
        final map = {
          'a': 1,
          'b': null,
          'c': 'value',
          'd': null,
        };
        final result = JsonHelper.removeNulls(map);
        expect(result.containsKey('a'), isTrue);
        expect(result.containsKey('b'), isFalse);
        expect(result.containsKey('c'), isTrue);
        expect(result.containsKey('d'), isFalse);
      });

      test('should handle null map', () {
        expect(JsonHelper.removeNulls(null), <String, dynamic>{});
      });

      test('should preserve non-null values', () {
        final map = {
          'a': 0,
          'b': false,
          'c': '',
        };
        final result = JsonHelper.removeNulls(map);
        expect(result['a'], 0);
        expect(result['b'], false);
        expect(result['c'], '');
      });
    });

    group('toQueryString', () {
      test('should convert map to query string', () {
        final map = {'key1': 'value1', 'key2': 'value2'};
        final result = JsonHelper.toQueryString(map);
        expect(result, contains('key1=value1'));
        expect(result, contains('key2=value2'));
        expect(result, contains('&'));
      });

      test('should URL encode values', () {
        final map = {'key': 'value with spaces'};
        final result = JsonHelper.toQueryString(map);
        expect(result, contains('value%20with%20spaces'));
      });

      test('should handle null map', () {
        expect(JsonHelper.toQueryString(null), '');
      });

      test('should handle empty map', () {
        expect(JsonHelper.toQueryString({}), '');
      });

      test('should skip null values', () {
        final map = {'key1': 'value1', 'key2': null};
        final result = JsonHelper.toQueryString(map);
        expect(result, contains('key1=value1'));
        expect(result, isNot(contains('key2')));
      });

      test('should handle numeric values', () {
        final map = {'num': 123, 'double': 45.67};
        final result = JsonHelper.toQueryString(map);
        expect(result, contains('num=123'));
        expect(result, contains('double=45.67'));
      });

      test('should handle boolean values', () {
        final map = {'flag1': true, 'flag2': false};
        final result = JsonHelper.toQueryString(map);
        expect(result, contains('flag1=true'));
        expect(result, contains('flag2=false'));
      });

      test('should handle special characters in keys', () {
        final map = {'key with spaces': 'value'};
        final result = JsonHelper.toQueryString(map);
        expect(result, contains('key%20with%20spaces'));
      });
    });

    group('Edge Cases - Additional Coverage', () {
      test('should handle getInt with double value', () {
        final map = {'key': 123.0};
        expect(JsonHelper.getInt(map, 'key'), 123);
      });

      test('should handle getInt with large number', () {
        final map = {'key': 999999999};
        expect(JsonHelper.getInt(map, 'key'), 999999999);
      });

      test('should handle getDouble with int value', () {
        final map = {'key': 123};
        expect(JsonHelper.getDouble(map, 'key'), 123.0);
      });

      test('should handle getDouble with large number', () {
        final map = {'key': 123.456789};
        expect(JsonHelper.getDouble(map, 'key'), 123.456789);
      });

      test('should handle getDouble with invalid string', () {
        final map = {'key': 'not-a-number'};
        expect(JsonHelper.getDouble(map, 'key'), isNull);
      });

      test('should handle getInt with invalid string', () {
        final map = {'key': 'not-a-number'};
        expect(JsonHelper.getInt(map, 'key'), isNull);
      });

      test('should handle getInt with null map', () {
        expect(JsonHelper.getInt(null, 'key'), isNull);
      });

      test('should handle getDouble with null map', () {
        expect(JsonHelper.getDouble(null, 'key'), isNull);
      });

      test('should handle getBool with null map', () {
        expect(JsonHelper.getBool(null, 'key'), isNull);
      });

      test('should handle getList with null map', () {
        expect(JsonHelper.getList(null, 'key'), isNull);
      });

      test('should handle getMap with null map', () {
        expect(JsonHelper.getMap(null, 'key'), isNull);
      });

      test('should handle getString with null map', () {
        expect(JsonHelper.getString(null, 'key'), isNull);
      });

      test('should handle deepMerge with nested non-map values', () {
        final map1 = {'key': 'old'};
        final map2 = {
          'key': {'nested': 'value'},
        };
        final result = JsonHelper.deepMerge(map1, map2);
        expect(result['key'], isA<Map<String, dynamic>>());
      });

      test('should handle deepMerge with map1 having nested map', () {
        final map1 = {
          'key': {'nested': 'old'},
        };
        final map2 = {'key': 'new'};
        final result = JsonHelper.deepMerge(map1, map2);
        expect(result['key'], 'new');
      });

      test('should handle encodePretty with list', () {
        final list = [1, 2, 3];
        final result = JsonHelper.encodePretty(list);
        expect(result, isNotNull);
        expect(result, contains('1'));
      });

      test('should handle encodePretty with nested structures', () {
        final map = {
          'key': 'value',
          'nested': {'a': 1, 'b': 2},
        };
        final result = JsonHelper.encodePretty(map);
        expect(result, isNotNull);
        expect(result, contains('"key"'));
        expect(result, contains('"nested"'));
      });

      test('should handle getListOf with empty list', () {
        final map = {'items': <dynamic>[]};
        final result = JsonHelper.getListOf<String>(
          map,
          'items',
          (item) => item.toString(),
        );
        expect(result, isEmpty);
      });

      test('should handle getListOf with null list', () {
        final map = {'items': null};
        final result = JsonHelper.getListOf<String>(
          map,
          'items',
          (item) => item.toString(),
        );
        expect(result, isNull);
      });

      test('should handle removeNulls with all null values', () {
        final map = {'a': null, 'b': null, 'c': null};
        final result = JsonHelper.removeNulls(map);
        expect(result, isEmpty);
      });

      test('should handle removeNulls with no null values', () {
        final map = {'a': 1, 'b': 2, 'c': 3};
        final result = JsonHelper.removeNulls(map);
        expect(result.length, 3);
      });

      test('should handle toQueryString with single entry', () {
        final map = {'key': 'value'};
        final result = JsonHelper.toQueryString(map);
        expect(result, 'key=value');
      });

      test('should handle toQueryString with all null values', () {
        final map = {'key1': null, 'key2': null};
        final result = JsonHelper.toQueryString(map);
        expect(result, isEmpty);
      });
    });
  });
}
