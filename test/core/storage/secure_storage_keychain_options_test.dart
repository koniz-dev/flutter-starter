// SecureStorageService's Keychain accessibility, pinned.
//
// `first_unlock_this_device` keeps tokens off backups and new devices; a
// downgrade to `first_unlock` lets them migrate. The plugin sends the iOS
// options only when `Platform.isIOS`, so a host test reads the options the
// instance was built with instead of the method channel. macOS used to get
// the plugin's default, `unlocked`.

import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('criterion 1: iOS Keychain items are first_unlock_this_device', () {
    final plugin = SecureStorageService().plugin;

    expect(
      plugin.iOptions.toMap()['accessibility'],
      'first_unlock_this_device',
    );
    expect(identical(plugin.iOptions, SecureStorageService.iosOptions), isTrue);
  });

  test(
    'criterion 2: macOS Keychain items are first_unlock_this_device too',
    () {
      final plugin = SecureStorageService().plugin;

      expect(
        plugin.mOptions.toMap()['accessibility'],
        'first_unlock_this_device',
      );
      expect(
        identical(plugin.mOptions, SecureStorageService.macOsOptions),
        isTrue,
      );
    },
  );
}
