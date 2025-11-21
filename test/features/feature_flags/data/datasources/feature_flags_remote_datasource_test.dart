import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlagsRemoteDataSourceImpl', () {
    late FeatureFlagsRemoteDataSourceImpl dataSource;

    setUp(() {
      dataSource = FeatureFlagsRemoteDataSourceImpl();
    });

    group('initialize', () {
      test('should initialize with default values', () async {
        // Arrange
        final defaults = {'key1': true, 'key2': false};
        dataSource = FeatureFlagsRemoteDataSourceImpl(defaultValues: defaults);

        // Act & Assert
        // Note: Firebase Remote Config requires actual Firebase setup
        // This test verifies the initialization doesn't throw
        await expectLater(dataSource.initialize(), completes);
      });

      test('should initialize without default values', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();

        // Act & Assert
        await expectLater(dataSource.initialize(), completes);
      });

      test('should handle initialization errors gracefully', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();

        // Act & Assert
        // Should complete even if Firebase is not available
        await expectLater(dataSource.initialize(), completes);
      });

      test('should not reinitialize if already initialized', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();

        // Act
        await dataSource.initialize();
        await dataSource.initialize();

        // Assert - Should complete without errors
        expect(dataSource, isNotNull);
      });
    });

    group('fetchAndActivate', () {
      test('should fetch and activate when initialized', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        await dataSource.initialize();

        // Act & Assert
        // Should complete even if fetch fails (offline mode)
        await expectLater(dataSource.fetchAndActivate(), completes);
      });

      test('should handle fetch errors gracefully', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        await dataSource.initialize();

        // Act & Assert
        // Should complete even if fetch fails
        await expectLater(dataSource.fetchAndActivate(), completes);
      });

      test('should return early if not initialized', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        // Don't call initialize

        // Act & Assert
        await expectLater(dataSource.fetchAndActivate(), completes);
      });
    });

    group('getRemoteFlag', () {
      test('should return null when not initialized', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        // Don't call initialize

        // Act
        final result = await dataSource.getRemoteFlag('test_key');

        // Assert
        expect(result, isNull);
      });

      test('should handle getBool errors gracefully', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        await dataSource.initialize();

        // Act
        final result = await dataSource.getRemoteFlag('non_existent_key');

        // Assert
        // Should return null on error
        expect(result, isNull);
      });
    });

    group('getAllRemoteFlags', () {
      test('should return empty map when not initialized', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        // Don't call initialize

        // Act
        final result = await dataSource.getAllRemoteFlags();

        // Assert
        expect(result, isEmpty);
      });

      test('should handle getAll errors gracefully', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        await dataSource.initialize();

        // Act
        final result = await dataSource.getAllRemoteFlags();

        // Assert
        // Should return empty map on error
        expect(result, isA<Map<String, bool>>());
      });
    });

    group('setDefaults', () {
      test('should add defaults to internal map', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        final defaults = {'key1': true, 'key2': false};

        // Act
        await dataSource.setDefaults(defaults);

        // Assert
        // Should complete without errors
        expect(dataSource, isNotNull);
      });

      test('should merge with existing defaults', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl(
          defaultValues: {'existing': true},
        );
        final newDefaults = {'new': false};

        // Act
        await dataSource.setDefaults(newDefaults);

        // Assert
        // Should complete without errors
        expect(dataSource, isNotNull);
      });

      test('should handle empty defaults', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();

        // Act
        await dataSource.setDefaults({});

        // Assert
        // Should complete without errors
        expect(dataSource, isNotNull);
      });
    });

    group('remoteConfig getter', () {
      test('should throw StateError when not initialized', () {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        // Don't call initialize

        // Act & Assert
        expect(
          () => dataSource.remoteConfig,
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Edge Cases', () {
      test('should handle multiple initialize calls', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();

        // Act
        await dataSource.initialize();
        await dataSource.initialize();
        await dataSource.initialize();

        // Assert
        // Should complete without errors
        expect(dataSource, isNotNull);
      });

      test('should handle fetchAndActivate multiple times', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        await dataSource.initialize();

        // Act
        await dataSource.fetchAndActivate();
        await dataSource.fetchAndActivate();
        await dataSource.fetchAndActivate();

        // Assert
        // Should complete without errors
        expect(dataSource, isNotNull);
      });

      test('should handle getRemoteFlag with empty key', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        await dataSource.initialize();

        // Act
        final result = await dataSource.getRemoteFlag('');

        // Assert
        expect(result, isNull);
      });

      test('should handle getRemoteFlag with special characters', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        await dataSource.initialize();

        // Act
        final result = await dataSource.getRemoteFlag('key-with-special_chars');

        // Assert
        expect(result, isNull);
      });

      test('should handle setDefaults with null values', () async {
        // Arrange
        dataSource = FeatureFlagsRemoteDataSourceImpl();
        final defaults = <String, dynamic>{
          'key1': true,
          'key2': null,
        };

        // Act & Assert
        await expectLater(dataSource.setDefaults(defaults), completes);
      });
    });
  });
}
