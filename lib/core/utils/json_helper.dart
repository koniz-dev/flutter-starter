import 'dart:convert';

/// JSON helper utilities for safe JSON operations
class JsonHelper {
  JsonHelper._();

  static final BigInt _minInt64 = -(BigInt.one << 63);
  static final BigInt _maxInt64 = (BigInt.one << 63) - BigInt.one;
  static final _decimalDigits = RegExp(r'^[0-9]+$');
  static final _hexDigits = RegExp(r'^[0-9a-fA-F]+$');
  static final _leadingZeroes = RegExp('^0+');

  /// Safely decode a JSON string to a Map or List
  /// Returns null if decoding fails
  static dynamic decode(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(jsonString);
    } on FormatException {
      return null;
    }
  }

  /// Safely decode a JSON string to a `Map<String, dynamic>`
  /// Returns null if decoding fails or result is not a Map
  static Map<String, dynamic>? decodeMap(String? jsonString) {
    final decoded = decode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  /// Safely decode a JSON string to a List
  /// Returns null if decoding fails or result is not a List
  static List<dynamic>? decodeList(String? jsonString) {
    final decoded = decode(jsonString);
    if (decoded is List) {
      return decoded;
    }
    return null;
  }

  /// Encode an object to a JSON string
  /// Returns null if encoding fails
  static String? encode(dynamic object) {
    try {
      return jsonEncode(object);
    } on Object catch (_) {
      // Catch all exceptions and errors (FormatException, TypeError, etc.)
      return null;
    }
  }

  /// Encode an object to a pretty-printed JSON string
  /// Returns null if encoding fails
  static String? encodePretty(dynamic object) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(object);
    } on Exception catch (_) {
      return null;
    } on Object catch (_) {
      // Catch all other errors (TypeError, etc.)
      return null;
    }
  }

  /// Safely get a value from a Map by key
  /// Returns null if key doesn't exist or map is null
  static T? getValue<T>(Map<String, dynamic>? map, String key) {
    if (map == null) return null;
    final value = map[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  /// Safely get a String value from a Map by key
  static String? getString(Map<String, dynamic>? map, String key) {
    return getValue<String>(map, key);
  }

  /// Gets an exact signed 64-bit integer representable on the current target.
  ///
  /// Accepts integral finite numbers and trimmed signed decimal/0x integer
  /// text. Fractions, non-finite values, overflow and target rounding return
  /// null. Existing precision loss before this call cannot be recovered.
  static int? getInt(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    final BigInt? integer;
    if (value is num) {
      if (!value.isFinite) return null;
      // JavaScript also considers large integral doubles to be int, so range
      // checking cannot be skipped merely because `value is int` is true.
      if (value is! int && value != value.truncateToDouble()) return null;
      integer = BigInt.from(value);
    } else if (value is String) {
      integer = _parseIntegerText(value);
    } else {
      return null;
    }
    if (integer == null || integer < _minInt64 || integer > _maxInt64) {
      return null;
    }
    final result = integer.toInt();
    return BigInt.from(result) == integer ? result : null;
  }

  static BigInt? _parseIntegerText(String value) {
    var digits = value.trim();
    final negative = digits.startsWith('-');
    if (negative || digits.startsWith('+')) digits = digits.substring(1);
    final hex = digits.startsWith('0x') || digits.startsWith('0X');
    if (hex) digits = digits.substring(2);
    if (!(hex ? _hexDigits : _decimalDigits).hasMatch(digits)) return null;
    digits = digits.replaceFirst(_leadingZeroes, '');
    // Bound significant digits before BigInt parsing, even for huge inputs.
    if (digits.length > (hex ? 16 : 19)) return null;
    final magnitude = BigInt.parse(
      digits.isEmpty ? '0' : digits,
      radix: hex ? 16 : 10,
    );
    return negative ? -magnitude : magnitude;
  }

  /// Safely get a double value from a Map by key
  static double? getDouble(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safely get a bool value from a Map by key
  static bool? getBool(Map<String, dynamic>? map, String key) {
    return getValue<bool>(map, key);
  }

  /// Safely get a Map from a Map by key
  static Map<String, dynamic>? getMap(Map<String, dynamic>? map, String key) {
    return getValue<Map<String, dynamic>>(map, key);
  }

  /// Safely get a List from a Map by key
  static List<dynamic>? getList(Map<String, dynamic>? map, String key) {
    return getValue<List<dynamic>>(map, key);
  }

  /// Safely get a List of a specific type from a Map by key
  static List<T>? getListOf<T>(
    Map<String, dynamic>? map,
    String key,
    T Function(dynamic) converter,
  ) {
    final list = getList(map, key);
    if (list == null) return null;
    try {
      return list.map(converter).toList();
    } on Object {
      // Object, not Exception: a failed cast inside `converter` raises
      // TypeError, which is an Error.
      return null;
    }
  }

  /// Check if a JSON string is valid
  static bool isValidJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return false;
    }
    try {
      jsonDecode(jsonString);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Merge two JSON maps, with the second map taking precedence
  static Map<String, dynamic> merge(
    Map<String, dynamic>? map1,
    Map<String, dynamic>? map2,
  ) {
    final result = <String, dynamic>{};
    if (map1 != null) {
      result.addAll(map1);
    }
    if (map2 != null) {
      result.addAll(map2);
    }
    return result;
  }

  /// Deep merge two JSON maps
  static Map<String, dynamic> deepMerge(
    Map<String, dynamic>? map1,
    Map<String, dynamic>? map2,
  ) {
    if (map1 == null && map2 == null) return {};
    if (map1 == null) return Map<String, dynamic>.from(map2!);
    if (map2 == null) return Map<String, dynamic>.from(map1);

    final result = Map<String, dynamic>.from(map1);

    for (final entry in map2.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map<String, dynamic> &&
          result[key] is Map<String, dynamic>) {
        result[key] = deepMerge(result[key] as Map<String, dynamic>, value);
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  /// Remove null values from a Map
  static Map<String, dynamic> removeNulls(Map<String, dynamic>? map) {
    if (map == null) return {};
    return Map.fromEntries(map.entries.where((entry) => entry.value != null));
  }

  /// Convert a Map to a query string format
  static String toQueryString(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return '';
    return map.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}='
              '${Uri.encodeComponent(entry.value.toString())}',
        )
        .join('&');
  }
}
