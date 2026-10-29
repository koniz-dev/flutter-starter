import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

void main() {
  test('two overrides set together are both indexed and both cleared', () async {
    final store = InMemoryKeyValueStore();
    final ds = FeatureFlagsLocalDataSourceImpl(storageService: store);

    await Future.wait([
      ds.setLocalOverride('flag_a', value: true),
      ds.setLocalOverride('flag_b', value: true),
    ]);

    final listed = await ds.getAllLocalOverrides();
    print('listed=$listed');
    await ds.clearAllLocalOverrides();
    final a = await ds.getLocalOverride('flag_a');
    final b = await ds.getLocalOverride('flag_b');
    print('after clearAll: flag_a=$a flag_b=$b');
    expect(listed.keys, unorderedEquals(['flag_a', 'flag_b']));
    expect([a, b], [null, null]);
  });
}
