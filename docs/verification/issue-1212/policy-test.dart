import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/repositories/feature_flags_repository_impl.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Remote extends Mock implements FeatureFlagsRemoteDataSource {}

class _Local extends Mock implements FeatureFlagsLocalDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var loads = 0;
  Future<void> loadPolicy({required bool enabled}) async {
    final fileName = 'override_policy_${loads++}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          if (utf8.decode(message!.buffer.asUint8List()) != fileName) {
            return null;
          }
          final bytes = Uint8List.fromList(
            utf8.encode(
              'ENVIRONMENT=production\nENABLE_DEBUG_FEATURES=$enabled\n',
            ),
          );
          return ByteData.view(bytes.buffer);
        });
    await EnvConfig.load(fileName: fileName);
    expect(AppConfig.enableDebugFeatures, enabled);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  for (final enabled in [false, true]) {
    for (final method in ['getFlag', 'getFlags', 'getAllFlags']) {
      test('$method respects debug features enabled=$enabled', () async {
        await loadPolicy(enabled: enabled);
        const key = 'remote_kill_switch';
        final local = _Local();
        final remote = _Remote();
        when(() => local.getLocalOverride(key)).thenAnswer((_) async => true);
        when(local.getAllLocalOverrides).thenAnswer(
          (_) async => {key: true},
        );
        when(() => remote.getRemoteFlag(key)).thenAnswer((_) async => false);
        when(remote.getAllRemoteFlags).thenAnswer(
          (_) async => {key: false},
        );
        final repository = FeatureFlagsRepositoryImpl(
          remoteDataSource: remote,
          localDataSource: local,
        );

        final flag = switch (method) {
          'getFlag' => (await repository.getFlag(key)).dataOrNull,
          'getFlags' => (await repository.getFlags([key])).dataOrNull?[key],
          _ => (await repository.getAllFlags()).dataOrNull?[key],
        };

        expect(flag, isNotNull);
        expect(flag!.value, enabled);
        expect(
          flag.source,
          enabled
              ? FeatureFlagSource.localOverride
              : FeatureFlagSource.remoteConfig,
        );
        if (enabled) {
          if (method == 'getAllFlags') {
            verify(local.getAllLocalOverrides).called(1);
          } else {
            verify(() => local.getLocalOverride(key)).called(1);
          }
        } else {
          verifyNever(() => local.getLocalOverride(any()));
          verifyNever(local.getAllLocalOverrides);
        }
      });
    }
  }
}
