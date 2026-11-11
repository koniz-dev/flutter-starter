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
import 'package:flutter_starter/features/feature_flags/domain/feature_flags_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test/helpers/in_memory_stores.dart';
class Remote extends Mock implements FeatureFlagsRemoteDataSource {}
class Store extends InMemoryKeyValueStore {
 int reads = 0;
 @override Future<String?> getString(String key) { reads++; return super.getString(key); }
 @override Future<List<String>?> getStringList(String key) { reads++; return super.getStringList(key); }
}
void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 var seq = 0;
 for (final environment in ['production', 'staging', 'development']) {
  for (final explicit in [null, true, false]) {
   test('$environment explicit=$explicit real persisted overrides across every caller', () async {
    final fileName = 'review_policy_${seq++}';
    final content = 'ENVIRONMENT=$environment\n${explicit == null ? "" : "ENABLE_DEBUG_FEATURES=$explicit\n"}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
     if (utf8.decode(message!.buffer.asUint8List()) != fileName) return null;
     final bytes = Uint8List.fromList(utf8.encode(content));
     return ByteData.view(bytes.buffer);
    });
    await EnvConfig.load(fileName:fileName);
    final enabled = explicit ?? environment == 'development';
    expect(AppConfig.enableDebugFeatures, enabled);
    final store = Store();
    final local = FeatureFlagsLocalDataSourceImpl(storageService:store);
    const remoteKey = FeatureFlagKey(value:'remote_kill_switch',defaultValue:true,description:'probe');
    const unknownKey = 'override_only';
    const definedKey = 'enable_experimental_features';
    for (final key in [remoteKey.value, unknownKey, definedKey]) { await local.setLocalOverride(key,value:true); }
    final persisted = Map<String,Object?>.from(store.values);
    store.reads=0;
    final remote=Remote();
    when(() => remote.getRemoteFlag(any())).thenAnswer((invocation) async => invocation.positionalArguments.single == remoteKey.value ? false : null);
    when(remote.getAllRemoteFlags).thenAnswer((_) async => {remoteKey.value:false});
    final repo=FeatureFlagsRepositoryImpl(remoteDataSource:remote, localDataSource:local);
    final manager=FeatureFlagsManager(repo);
    expect((await repo.getFlag(remoteKey.value)).dataOrNull?.value,enabled);
    expect((await repo.getFlags([remoteKey.value])).dataOrNull?[remoteKey.value]?.value,enabled);
    expect((await repo.getAllFlags()).dataOrNull?[remoteKey.value]?.value,enabled);
    expect((await repo.isEnabled(remoteKey.value)).dataOrNull,enabled);
    expect(await manager.isEnabled(remoteKey),enabled);
    expect((await manager.getFlag(remoteKey))?.value,enabled);
    expect((await manager.getFlags([remoteKey]))[remoteKey.value],enabled);
    expect((await repo.getFlag(definedKey)).dataOrNull?.value,enabled);
    expect((await repo.getAllFlags()).dataOrNull?.containsKey(unknownKey),enabled);
    expect((await repo.getFlag(unknownKey)).isSuccess,enabled);
    expect(store.values,persisted,reason:'Policy must ignore rather than destroy persisted data');
    expect(store.reads,enabled ? greaterThan(0) : 0);
    if (enabled) { expect((await repo.getFlag(remoteKey.value)).dataOrNull?.source,FeatureFlagSource.localOverride); }
   });
  }
 }
 tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',null));
}
