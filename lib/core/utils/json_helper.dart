import 'dart:convert';

/// JSON helper utilities for safe JSON operations
class JsonHelper {
  JsonHelper._();

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
    } on Exception {
      return null;
    }
  }

  /// Encode an object to a pretty-printed JSON string
  /// Returns null if encoding fails
  static String? encodePretty(dynamic object) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(object);
    } on Exception {
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

  /// Safely get an int value from a Map by key
  static int? getInt(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
  static Map<String, dynamic>? getMap(
    Map<String, dynamic>? map,
    String key,
  ) {
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
    } on Exception {
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
        result[key] = deepMerge(
          result[key] as Map<String, dynamic>,
          value,
        );
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  /// Remove null values from a Map
  static Map<String, dynamic> removeNulls(Map<String, dynamic>? map) {
    if (map == null) return {};
    return Map.fromEntries(
      map.entries.where((entry) => entry.value != null),
    );
  }

  /// Convert a Map to a query string format
  static String toQueryString(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return '';
    return map.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${Uri.encodeComponent(entry.key)}='
            '${Uri.encodeComponent(entry.value.toString())}',
        )
        .join('&');
  }
}
