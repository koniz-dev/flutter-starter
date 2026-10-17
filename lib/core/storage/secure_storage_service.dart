import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/string_list_encoding.dart';

/// Secure storage service implementation using flutter_secure_storage
///
/// This service provides encrypted storage for sensitive data such as:
/// - Authentication tokens
/// - Passwords
/// - API keys
/// - Other sensitive information
///
/// Platform-specific configuration (koniz-dev/flutter-starter#571):
/// - iOS and macOS: Keychain items are `first_unlock_this_device` - readable
///   after the first unlock since boot, and never migrated to a backup or a
///   new device. macOS used to get the plugin's default, `unlocked`, because
///   only the iOS options were passed. See [iosOptions] and [macOsOptions].
///
/// String lists are stored as a JSON array (see `string_list_encoding.dart`),
/// so any element round-trips - including one holding a comma, and `['']`.
/// A list written before koniz-dev/flutter-starter#281 in the old
/// comma-joined form still reads back, split on commas as it was written.
class SecureStorageService implements IStorageService, IStrictStringRead {
  /// Creates a [SecureStorageService] instance with platform-specific options
  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        iOptions: iosOptions,
        mOptions: macOsOptions,
      );

  /// The Keychain options passed on iOS.
  ///
  /// Named so a test can check them: the plugin sends them only when
  /// `dart:io`'s `Platform.isIOS` is true, so a host `flutter test` never sees
  /// them on the method channel (koniz-dev/flutter-starter#374).
  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// The Keychain options passed on macOS; the same accessibility as iOS.
  static const MacOsOptions macOsOptions = MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  /// The plugin instance, so a test can read the options it was built with.
  @visibleForTesting
  FlutterSecureStorage get plugin => _storage;

  @override
  Future<String?> getString(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception {
      // Return null on error (e.g., storage unavailable)
      return null;
    }
  }

  /// Reads [key] and lets a Keychain or Keystore failure propagate.
  ///
  /// [getString] returns `null` on such a failure, which is the same answer
  /// as a missing key. The storage migration must not confuse the two - see
  /// [IStrictStringRead].
  @override
  Future<String?> getStringOrThrow(String key) => _storage.read(key: key);

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
      return decodeStringList(value);
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      await _storage.write(key: key, value: encodeStringList(value));
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
