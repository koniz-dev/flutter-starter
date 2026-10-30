// The override index is read, changed and written back. Two overrides set
// together - the debug screen's switches call setLocalOverride with no
// pending guard - each read the same old list, and the second write dropped
// the first key: it was not listed, and clearAllLocalOverrides left it
// active.

import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

void main() {
  late FeatureFlagsLocalDataSourceImpl dataSource;

  setUp(() {
    dataSource = FeatureFlagsLocalDataSourceImpl(
      storageService: InMemoryKeyValueStore(),
    );
  });

  test('two overrides set together are both listed', () async {
    await Future.wait([
      dataSource.setLocalOverride('flag_a', value: true),
      dataSource.setLocalOverride('flag_b', value: false),
    ]);

    expect(await dataSource.getAllLocalOverrides(), {
      'flag_a': true,
      'flag_b': false,
    });
  });

  test('clearAllLocalOverrides clears both', () async {
    await Future.wait([
      dataSource.setLocalOverride('flag_a', value: true),
      dataSource.setLocalOverride('flag_b', value: true),
    ]);

    await dataSource.clearAllLocalOverrides();

    expect(await dataSource.getLocalOverride('flag_a'), isNull);
    expect(await dataSource.getLocalOverride('flag_b'), isNull);
  });

  test('an add and a remove issued together both take effect', () async {
    await dataSource.setLocalOverride('flag_a', value: true);

    await Future.wait([
      dataSource.clearLocalOverride('flag_a'),
      dataSource.setLocalOverride('flag_b', value: true),
    ]);

    expect(await dataSource.getAllLocalOverrides(), {'flag_b': true});
  });
}
