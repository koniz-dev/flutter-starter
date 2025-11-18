import 'package:shared_preferences/shared_preferences.dart';

/// Abstract interface for storage operations
abstract class IStorageService {
  /// Retrieves a string value from storage by [key]
  Future<String?> getString(String key);

  /// Stores a string [value] in storage with the given [key]
  Future<bool> setString(String key, String value);

  /// Retrieves an integer value from storage by [key]
  Future<int?> getInt(String key);

  /// Stores an integer [value] in storage with the given [key]
  Future<bool> setInt(String key, int value);

  /// Retrieves a boolean value from storage by [key]
  Future<bool?> getBool(String key);

  /// Stores a boolean [value] in storage with the given [key]
  Future<bool> setBool(String key, {required bool value});

  /// Retrieves a double value from storage by [key]
  Future<double?> getDouble(String key);

  /// Stores a double [value] in storage with the given [key]
  Future<bool> setDouble(String key, double value);

  /// Retrieves a list of strings from storage by [key]
  Future<List<String>?> getStringList(String key);

  /// Stores a list of strings [value] in storage with the given [key]
  Future<bool> setStringList(String key, List<String> value);

  /// Removes a value from storage by [key]
  Future<bool> remove(String key);

  /// Clears all values from storage
  Future<bool> clear();

  /// Checks if storage contains a value for the given [key]
  Future<bool> containsKey(String key);
}

/// Implementation of storage service using SharedPreferences
class StorageService implements IStorageService {
  SharedPreferences? _prefs;

  /// Get SharedPreferences instance (lazy initialization)
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Initialize storage service (optional, for explicit initialization)
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    final prefs = await _preferences;
    return prefs.setString(key, value);
  }

  @override
  Future<int?> getInt(String key) async {
    final prefs = await _preferences;
    return prefs.getInt(key);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    final prefs = await _preferences;
    return prefs.setInt(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    final prefs = await _preferences;
    return prefs.getBool(key);
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    final prefs = await _preferences;
    return prefs.setBool(key, value);
  }

  @override
  Future<double?> getDouble(String key) async {
    final prefs = await _preferences;
    return prefs.getDouble(key);
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    final prefs = await _preferences;
    return prefs.setDouble(key, value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final prefs = await _preferences;
    return prefs.getStringList(key);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    final prefs = await _preferences;
    return prefs.setStringList(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    final prefs = await _preferences;
    return prefs.remove(key);
  }

  @override
  Future<bool> clear() async {
    final prefs = await _preferences;
    return prefs.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    final prefs = await _preferences;
    return prefs.containsKey(key);
  }
}
