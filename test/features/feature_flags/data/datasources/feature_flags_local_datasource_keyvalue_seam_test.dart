/// Proves the [FeatureFlagsLocalDataSourceImpl] storage seam is real, not
/// nominal.
///
/// The store handed in here implements **only** `IKeyValueStore`. It is not a
/// `StorageService`, there is no `SharedPreferences.setMockInitialValues`, and
/// no platform channel is touched.
library;

import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

void main() {
  group('FeatureFlagsLocalDataSourceImpl on a bare IKeyValueStore', () {
    late InMemoryKeyValueStore store;
    late FeatureFlagsLocalDataSourceImpl dataSource;

    setUp(() {
      store = InMemoryKeyValueStore();
      dataSource = FeatureFlagsLocalDataSourceImpl(storageService: store);
    });

    test('writes an override and reads it back', () async {
      await dataSource.setLocalOverride('new_checkout', value: true);

      expect(await dataSource.getLocalOverride('new_checkout'), isTrue);
      expect(await dataSource.getAllLocalOverrides(), {'new_checkout': true});
    });

    test('persists under the unchanged feature_flag_override_ keys', () async {
      await dataSource.setLocalOverride('new_checkout', value: false);

      expect(store.values['feature_flag_override_new_checkout'], 'false');
      expect(store.values['feature_flag_override_keys'], ['new_checkout']);
    });

    test('clearLocalOverride drops the value and its tracking entry', () async {
      await dataSource.setLocalOverride('new_checkout', value: true);
      await dataSource.clearLocalOverride('new_checkout');

      expect(await dataSource.getLocalOverride('new_checkout'), isNull);
      expect(store.values, isEmpty);
    });
  });
}
