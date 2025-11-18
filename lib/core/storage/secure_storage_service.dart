import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

/// Secure storage service implementation using flutter_secure_storage
///
/// This service provides encrypted storage for sensitive data such as:
/// - Authentication tokens
/// - Passwords
/// - API keys
/// - Other sensitive information
///
/// Platform-specific configuration:
/// - Android: Uses EncryptedSharedPreferences
/// - iOS: Uses Keychain with first unlock accessibility
class SecureStorageService implements IStorageService {
  /// Creates a [SecureStorageService] instance with platform-specific options
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getString(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception {
      // Return null on error (e.g., storage unavailable)
      return null;
    }
  }

  @override
  Future<bool> setString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } on Exception {
      // Return false on error (e.g., storage unavailable, quota exceeded)
      return false;
    }
  }

  @override
  Future<int?> getInt(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      return int.tryParse(value);
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> setInt(String key, int value) async {
    try {
      await _storage.write(key: key, value: value.toString());
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      return value.toLowerCase() == 'true';
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    try {
      await _storage.write(key: key, value: value.toString());
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<double?> getDouble(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      return double.tryParse(value);
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    try {
      await _storage.write(key: key, value: value.toString());
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      // Store as comma-separated values
      // Handle empty string case (empty list stored as empty string)
      if (value.isEmpty) return <String>[];
      return value.split(',');
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      // Store as comma-separated values
      await _storage.write(key: key, value: value.join(','));
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    try {
      await _storage.delete(key: key);
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      await _storage.deleteAll();
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null;
    } on Exception {
      return false;
    }
  }
}
