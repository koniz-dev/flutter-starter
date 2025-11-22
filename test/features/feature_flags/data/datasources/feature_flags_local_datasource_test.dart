import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  group('FeatureFlagsLocalDataSourceImpl', () {
    late FeatureFlagsLocalDataSourceImpl dataSource;
    late MockStorageService mockStorageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockStorageService = MockStorageService();
      dataSource = FeatureFlagsLocalDataSourceImpl(
        storageService: mockStorageService,
      );
    });

    group('getLocalOverride', () {
      test('should return true when value is "true"', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => 'true');

        // Act
        final result = await dataSource.getLocalOverride('test_key');

        // Assert
        expect(result, isTrue);
        verify(
          () => mockStorageService.getString('feature_flag_override_test_key'),
        ).called(1);
      });

      test('should return false when value is "false"', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => 'false');

        // Act
        final result = await dataSource.getLocalOverride('test_key');

        // Assert
        expect(result, isFalse);
      });

      test('should return null when value is null', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => null);

        // Act
        final result = await dataSource.getLocalOverride('test_key');

        // Assert
        expect(result, isNull);
      });

      test('should return null when value is empty string', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => '');

        // Act
        final result = await dataSource.getLocalOverride('test_key');

        // Assert
        expect(result, isNull);
      });

      test('should handle different keys', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => 'true');

        // Act
        final result1 = await dataSource.getLocalOverride('key1');
        final result2 = await dataSource.getLocalOverride('key2');

        // Assert
        expect(result1, isTrue);
        expect(result2, isTrue);
        verify(() => mockStorageService.getString('feature_flag_override_key1'))
            .called(1);
        verify(() => mockStorageService.getString('feature_flag_override_key2'))
            .called(1);
      });
    });

    group('setLocalOverride', () {
      test('should set override value to true', () async {
        // Arrange
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => []);
        when(() => mockStorageService.setStringList(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.setLocalOverride('test_key', value: true);

        // Assert
        verify(
          () => mockStorageService.setString(
            'feature_flag_override_test_key',
            'true',
          ),
        ).called(1);
        verify(
          () => mockStorageService.getStringList('feature_flag_override_keys'),
        ).called(1);
      });

      test('should set override value to false', () async {
        // Arrange
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => []);
        when(() => mockStorageService.setStringList(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.setLocalOverride('test_key', value: false);

        // Assert
        verify(
          () => mockStorageService.setString(
            'feature_flag_override_test_key',
            'false',
          ),
        ).called(1);
      });

      test('should add key to tracking list when setting override', () async {
        // Arrange
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => []);
        when(() => mockStorageService.setStringList(any(), any()))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.setStringList(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.setLocalOverride('new_key', value: true);

        // Assert
        verify(
          () => mockStorageService.setStringList(
            'feature_flag_override_keys',
            ['new_key'],
          ),
        ).called(1);
      });

      test('should not add duplicate key to tracking list', () async {
        // Arrange
        when(() => mockStorageService.setString(any(), any()))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => ['existing_key']);

        // Act
        await dataSource.setLocalOverride('existing_key', value: true);

        // Assert
        verifyNever(() => mockStorageService.setStringList(any(), any()));
      });
    });

    group('clearLocalOverride', () {
      test('should remove override key', () async {
        // Arrange
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => ['test_key']);
        when(() => mockStorageService.setStringList(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.clearLocalOverride('test_key');

        // Assert
        verify(
          () => mockStorageService.remove('feature_flag_override_test_key'),
        ).called(1);
      });

      test('should remove key from tracking list', () async {
        // Arrange
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);
        final keysList = ['key1', 'key2'];
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => List.from(keysList));
        when(() => mockStorageService.setStringList(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.clearLocalOverride('key1');

        // Assert
        verify(
          () => mockStorageService.setStringList(
            'feature_flag_override_keys',
            ['key2'],
          ),
        ).called(1);
      });

      test('should remove keys list when last key is removed', () async {
        // Arrange
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);
        final keysList = ['last_key'];
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => List.from(keysList));

        // Act
        await dataSource.clearLocalOverride('last_key');

        // Assert
        verify(() => mockStorageService.remove('feature_flag_override_keys'))
            .called(1);
        verifyNever(() => mockStorageService.setStringList(any(), any()));
      });

      test('should handle clearing non-existent key', () async {
        // Arrange
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => []);

        // Act
        await dataSource.clearLocalOverride('non_existent');

        // Assert
        verify(
          () => mockStorageService.remove('feature_flag_override_non_existent'),
        ).called(1);
      });
    });

    group('clearAllLocalOverrides', () {
      test('should remove all override keys', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => ['key1', 'key2', 'key3']);
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.clearAllLocalOverrides();

        // Assert
        verify(() => mockStorageService.remove('feature_flag_override_key1'))
            .called(1);
        verify(() => mockStorageService.remove('feature_flag_override_key2'))
            .called(1);
        verify(() => mockStorageService.remove('feature_flag_override_key3'))
            .called(1);
        verify(() => mockStorageService.remove('feature_flag_override_keys'))
            .called(1);
      });

      test('should handle empty keys list', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => []);
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.clearAllLocalOverrides();

        // Assert
        verify(() => mockStorageService.remove('feature_flag_override_keys'))
            .called(1);
        verifyNever(
          () => mockStorageService.remove('feature_flag_override_key1'),
        );
      });

      test('should handle null keys list', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => null);
        when(() => mockStorageService.remove(any()))
            .thenAnswer((_) async => true);

        // Act
        await dataSource.clearAllLocalOverrides();

        // Assert
        verify(() => mockStorageService.remove('feature_flag_override_keys'))
            .called(1);
      });
    });

    group('getAllLocalOverrides', () {
      test('should return all overrides', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => ['key1', 'key2']);
        when(() => mockStorageService.getString('feature_flag_override_key1'))
            .thenAnswer((_) async => 'true');
        when(() => mockStorageService.getString('feature_flag_override_key2'))
            .thenAnswer((_) async => 'false');

        // Act
        final result = await dataSource.getAllLocalOverrides();

        // Assert
        expect(result, {'key1': true, 'key2': false});
      });

      test('should skip null values', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => ['key1', 'key2']);
        when(() => mockStorageService.getString('feature_flag_override_key1'))
            .thenAnswer((_) async => 'true');
        when(() => mockStorageService.getString('feature_flag_override_key2'))
            .thenAnswer((_) async => null);

        // Act
        final result = await dataSource.getAllLocalOverrides();

        // Assert
        expect(result, {'key1': true});
      });

      test('should return empty map when no keys', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => []);

        // Act
        final result = await dataSource.getAllLocalOverrides();

        // Assert
        expect(result, isEmpty);
      });

      test('should return empty map when keys list is null', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => null);

        // Act
        final result = await dataSource.getAllLocalOverrides();

        // Assert
        expect(result, isEmpty);
      });

      test('should handle multiple overrides', () async {
        // Arrange
        when(() => mockStorageService.getStringList(any()))
            .thenAnswer((_) async => ['key1', 'key2', 'key3']);
        when(() => mockStorageService.getString('feature_flag_override_key1'))
            .thenAnswer((_) async => 'true');
        when(() => mockStorageService.getString('feature_flag_override_key2'))
            .thenAnswer((_) async => 'false');
        when(() => mockStorageService.getString('feature_flag_override_key3'))
            .thenAnswer((_) async => 'true');

        // Act
        final result = await dataSource.getAllLocalOverrides();

        // Assert
        expect(result.length, 3);
        expect(result['key1'], isTrue);
        expect(result['key2'], isFalse);
        expect(result['key3'], isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle special characters in key', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => 'true');

        // Act
        final result = await dataSource.getLocalOverride(
          'key-with-special_chars',
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockStorageService.getString(
            'feature_flag_override_key-with-special_chars',
          ),
        ).called(1);
      });

      test('should handle very long key names', () async {
        // Arrange
        final longKey = 'a' * 100;
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => 'true');

        // Act
        final result = await dataSource.getLocalOverride(longKey);

        // Assert
        expect(result, isTrue);
      });

      test('should handle empty key', () async {
        // Arrange
        when(() => mockStorageService.getString(any()))
            .thenAnswer((_) async => 'true');

        // Act
        final result = await dataSource.getLocalOverride('');

        // Assert
        expect(result, isTrue);
        verify(() => mockStorageService.getString('feature_flag_override_'))
            .called(1);
      });
    });
  });
}
