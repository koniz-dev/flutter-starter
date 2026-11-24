const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backing = <String, String>{};
  String? failingKey;

  setUp(() {
    backing
      ..clear()
      ..addAll({StorageVersion.versionKey: '1', 'user_name': 'alice'});
    failingKey = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          final key = args?['key'] as String? ?? '';
          switch (call.method) {
            case 'read':
              if (key == failingKey) {
                throw PlatformException(code: 'BadPaddingException');
              }
              return backing[key];
            case 'write':
              backing[key] = args?['value'] as String? ?? '';
              return null;
            case 'delete':
              backing.remove(key);
              return null;
          }
          return null;
        });
  });

  test('guide example: a failed read throws and keeps the stamp at 1, a '
      'healthy rerun migrates', () async {
    failingKey = 'user_name';
    await expectLater(
      MigrationV1ToV2().execute(SecureStorageService()),
      throwsA(isA<MigrationException>()),
    );
    expect(backing[StorageVersion.versionKey], '1');
    expect(backing['user_name'], 'alice');

    failingKey = null;
    await MigrationV1ToV2().execute(SecureStorageService());
    expect(backing[StorageVersion.versionKey], '2');
    expect(backing['username'], 'alice');
    expect(backing.containsKey('user_name'), isFalse);
  });

  test('guide helpers: hasLegacy throws on a failed read', () async {
    failingKey = 'sync_interval_minutes';
    await expectLater(
      hasLegacy(SecureStorageService(), 'sync_interval_minutes'),
      throwsA(isA<MigrationException>()),
    );
  });
}
