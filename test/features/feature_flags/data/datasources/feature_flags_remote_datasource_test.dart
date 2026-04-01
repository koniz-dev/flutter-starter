import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoOpFeatureFlagsRemoteDataSource', () {
    late FeatureFlagsRemoteDataSource dataSource;

    setUp(() {
      dataSource = const NoOpFeatureFlagsRemoteDataSource();
    });

    test('initialize completes', () async {
      await expectLater(dataSource.initialize(), completes);
    });

    test('fetchAndActivate completes', () async {
      await expectLater(dataSource.fetchAndActivate(), completes);
    });

    test('getRemoteFlag returns null', () async {
      expect(await dataSource.getRemoteFlag('any'), isNull);
    });

    test('getAllRemoteFlags returns empty map', () async {
      expect(await dataSource.getAllRemoteFlags(), isEmpty);
    });

    test('setDefaults completes', () async {
      await expectLater(dataSource.setDefaults({'a': true}), completes);
    });
  });
}
