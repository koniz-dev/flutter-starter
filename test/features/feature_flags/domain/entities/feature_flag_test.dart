import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlag', () {
    final now = DateTime.now();
    final later = now.add(const Duration(hours: 1));

    test('should create feature flag with required fields', () {
      // Arrange & Act
      const flag = FeatureFlag(
        key: 'test_flag',
        value: true,
        source: FeatureFlagSource.compileTime,
      );

      // Assert
      expect(flag.key, 'test_flag');
      expect(flag.value, isTrue);
      expect(flag.source, FeatureFlagSource.compileTime);
      expect(flag.description, isNull);
      expect(flag.defaultValue, isNull);
      expect(flag.lastUpdated, isNull);
    });

    test('should create feature flag with all fields', () {
      // Arrange & Act
      final flag = FeatureFlag(
        key: 'test_flag',
        value: true,
        source: FeatureFlagSource.remoteConfig,
        description: 'Test description',
        defaultValue: false,
        lastUpdated: now,
      );

      // Assert
      expect(flag.key, 'test_flag');
      expect(flag.value, isTrue);
      expect(flag.source, FeatureFlagSource.remoteConfig);
      expect(flag.description, 'Test description');
      expect(flag.defaultValue, isFalse);
      expect(flag.lastUpdated, now);
    });

    test('should create feature flag with false value', () {
      // Arrange & Act
      const flag = FeatureFlag(
        key: 'disabled_flag',
        value: false,
        source: FeatureFlagSource.environment,
      );

      // Assert
      expect(flag.value, isFalse);
    });

    group('copyWith', () {
      final originalFlag = FeatureFlag(
        key: 'original_key',
        value: true,
        source: FeatureFlagSource.compileTime,
        description: 'Original description',
        defaultValue: false,
        lastUpdated: now,
      );

      test('should return new flag with same values when no changes', () {
        // Act
        final copied = originalFlag.copyWith();

        // Assert
        expect(copied.key, originalFlag.key);
        expect(copied.value, originalFlag.value);
        expect(copied.source, originalFlag.source);
        expect(copied.description, originalFlag.description);
        expect(copied.defaultValue, originalFlag.defaultValue);
        expect(copied.lastUpdated, originalFlag.lastUpdated);
        expect(copied, originalFlag);
      });

      test('should update key', () {
        // Act
        final copied = originalFlag.copyWith(key: 'new_key');

        // Assert
        expect(copied.key, 'new_key');
        expect(copied.value, originalFlag.value);
        expect(copied.source, originalFlag.source);
        expect(copied.description, originalFlag.description);
      });

      test('should update value', () {
        // Act
        final copied = originalFlag.copyWith(value: false);

        // Assert
        expect(copied.value, isFalse);
        expect(copied.key, originalFlag.key);
        expect(copied.source, originalFlag.source);
      });

      test('should update source', () {
        // Act
        final copied = originalFlag.copyWith(
          source: FeatureFlagSource.remoteConfig,
        );

        // Assert
        expect(copied.source, FeatureFlagSource.remoteConfig);
        expect(copied.key, originalFlag.key);
        expect(copied.value, originalFlag.value);
      });

      test('should update description', () {
        // Act
        final copied = originalFlag.copyWith(description: 'New description');

        // Assert
        expect(copied.description, 'New description');
        expect(copied.key, originalFlag.key);
        expect(copied.value, originalFlag.value);
      });

      test('should keep original description when null is passed', () {
        // Act
        final copied = originalFlag.copyWith();

        // Assert
        // copyWith uses ?? operator, so null keeps original value
        expect(copied.description, originalFlag.description);
      });

      test('should update defaultValue', () {
        // Act
        final copied = originalFlag.copyWith(defaultValue: true);

        // Assert
        expect(copied.defaultValue, isTrue);
        expect(copied.key, originalFlag.key);
      });

      test('should update lastUpdated', () {
        // Arrange
        final newDate = later.add(const Duration(days: 1));

        // Act
        final copied = originalFlag.copyWith(lastUpdated: newDate);

        // Assert
        expect(copied.lastUpdated, newDate);
        expect(copied.key, originalFlag.key);
      });

      test('should update multiple fields', () {
        // Arrange
        final newDate = now.add(const Duration(days: 2));

        // Act
        final copied = originalFlag.copyWith(
          key: 'new_key',
          value: false,
          source: FeatureFlagSource.environment,
          description: 'New description',
          defaultValue: true,
          lastUpdated: newDate,
        );

        // Assert
        expect(copied.key, 'new_key');
        expect(copied.value, isFalse);
        expect(copied.source, FeatureFlagSource.environment);
        expect(copied.description, 'New description');
        expect(copied.defaultValue, isTrue);
        expect(copied.lastUpdated, newDate);
      });
    });

    group('equality', () {
      test('should be equal when key, value, and source are same', () {
        // Arrange
        final flag1 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
          description: 'Description 1',
          defaultValue: false,
          lastUpdated: now,
        );
        final flag2 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
          description: 'Description 2',
          defaultValue: true,
          lastUpdated: later,
        );

        // Act & Assert
        expect(flag1, flag2);
        expect(flag1 == flag2, isTrue);
      });

      test('should not be equal when key is different', () {
        // Arrange
        const flag1 = FeatureFlag(
          key: 'flag1',
          value: true,
          source: FeatureFlagSource.compileTime,
        );
        const flag2 = FeatureFlag(
          key: 'flag2',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Act & Assert
        expect(flag1, isNot(flag2));
        expect(flag1 == flag2, isFalse);
      });

      test('should not be equal when value is different', () {
        // Arrange
        const flag1 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );
        const flag2 = FeatureFlag(
          key: 'test_flag',
          value: false,
          source: FeatureFlagSource.compileTime,
        );

        // Act & Assert
        expect(flag1, isNot(flag2));
        expect(flag1 == flag2, isFalse);
      });

      test('should not be equal when source is different', () {
        // Arrange
        const flag1 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );
        const flag2 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.remoteConfig,
        );

        // Act & Assert
        expect(flag1, isNot(flag2));
        expect(flag1 == flag2, isFalse);
      });

      test('should be equal to itself', () {
        // Arrange
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Act & Assert
        expect(flag, flag);
        expect(flag == flag, isTrue);
      });

      test('should not be equal to null', () {
        // Arrange
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Act & Assert
        expect(flag, isNot(null));
      });

      test('should not be equal to different type', () {
        // Arrange
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Act & Assert
        expect(flag, isNot('string'));
        expect(flag, isNot(123));
        expect(flag, isNot(<String, dynamic>{}));
      });

      test(
        'should ignore description, defaultValue, and lastUpdated in equality',
        () {
        // Arrange
        final flag1 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
          description: 'Description 1',
          defaultValue: false,
          lastUpdated: now,
        );
        final flag2 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
          description: 'Description 2',
          defaultValue: true,
          lastUpdated: later,
        );

        // Act & Assert
        expect(flag1, flag2);
      });
    });

    group('hashCode', () {
      test('should have same hashCode for equal flags', () {
        // Arrange
        const flag1 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
          description: 'Description 1',
        );
        const flag2 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
          description: 'Description 2',
        );

        // Act & Assert
        expect(flag1.hashCode, flag2.hashCode);
      });

      test('should have different hashCode for different keys', () {
        // Arrange
        const flag1 = FeatureFlag(
          key: 'flag1',
          value: true,
          source: FeatureFlagSource.compileTime,
        );
        const flag2 = FeatureFlag(
          key: 'flag2',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Act & Assert
        expect(flag1.hashCode, isNot(flag2.hashCode));
      });

      test('should have different hashCode for different values', () {
        // Arrange
        const flag1 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );
        const flag2 = FeatureFlag(
          key: 'test_flag',
          value: false,
          source: FeatureFlagSource.compileTime,
        );

        // Act & Assert
        expect(flag1.hashCode, isNot(flag2.hashCode));
      });

      test('should have different hashCode for different sources', () {
        // Arrange
        const flag1 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );
        const flag2 = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.remoteConfig,
        );

        // Act & Assert
        expect(flag1.hashCode, isNot(flag2.hashCode));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        // Arrange
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Act
        final result = flag.toString();

        // Assert
        expect(result, contains('FeatureFlag'));
        expect(result, contains('test_flag'));
        expect(result, contains('true'));
        expect(result, contains('FeatureFlagSource.compileTime'));
      });

      test('should include all relevant fields in toString', () {
        // Arrange
        const flag = FeatureFlag(
          key: 'my_flag',
          value: false,
          source: FeatureFlagSource.remoteConfig,
        );

        // Act
        final result = flag.toString();

        // Assert
        expect(result, contains('my_flag'));
        expect(result, contains('false'));
        expect(result, contains('FeatureFlagSource.remoteConfig'));
      });
    });

    group('FeatureFlagSource enum', () {
      test('should have all expected values', () {
        // Assert
        expect(FeatureFlagSource.values.length, 5);
        expect(
          FeatureFlagSource.values,
          contains(FeatureFlagSource.compileTime),
        );
        expect(
          FeatureFlagSource.values,
          contains(FeatureFlagSource.environment),
        );
        expect(
          FeatureFlagSource.values,
          contains(FeatureFlagSource.buildMode),
        );
        expect(
          FeatureFlagSource.values,
          contains(FeatureFlagSource.remoteConfig),
        );
        expect(
          FeatureFlagSource.values,
          contains(FeatureFlagSource.localOverride),
        );
      });

      test('should work with all source types', () {
        // Arrange & Act
        const flags = [
          FeatureFlag(
            key: 'flag1',
            value: true,
            source: FeatureFlagSource.compileTime,
          ),
          FeatureFlag(
            key: 'flag2',
            value: true,
            source: FeatureFlagSource.environment,
          ),
          FeatureFlag(
            key: 'flag3',
            value: true,
            source: FeatureFlagSource.buildMode,
          ),
          FeatureFlag(
            key: 'flag4',
            value: true,
            source: FeatureFlagSource.remoteConfig,
          ),
          FeatureFlag(
            key: 'flag5',
            value: true,
            source: FeatureFlagSource.localOverride,
          ),
        ];

        // Assert
        expect(flags.length, 5);
        expect(flags[0].source, FeatureFlagSource.compileTime);
        expect(flags[1].source, FeatureFlagSource.environment);
        expect(flags[2].source, FeatureFlagSource.buildMode);
        expect(flags[3].source, FeatureFlagSource.remoteConfig);
        expect(flags[4].source, FeatureFlagSource.localOverride);
      });
    });

    group('edge cases', () {
      test('should handle empty key', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: '',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag.key, isEmpty);
        expect(flag.value, isTrue);
      });

      test('should handle long key', () {
        // Arrange
        final longKey = 'a' * 1000;

        // Act
        final flag = FeatureFlag(
          key: longKey,
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag.key.length, 1000);
      });

      test('should handle special characters in key', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: 'flag-123_abc.xyz',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag.key, 'flag-123_abc.xyz');
      });

      test('should handle unicode characters in key', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: 'flag_你好世界',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag.key, 'flag_你好世界');
      });

      test('should handle null description', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag.description, isNull);
      });

      test('should handle empty description', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
          description: '',
        );

        // Assert
        expect(flag.description, isEmpty);
      });

      test('should handle null defaultValue', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag.defaultValue, isNull);
      });

      test('should handle null lastUpdated', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag.lastUpdated, isNull);
      });
    });

    group('immutability', () {
      test('should be immutable (final fields)', () {
        // Arrange & Act
        const flag = FeatureFlag(
          key: 'test_flag',
          value: true,
          source: FeatureFlagSource.compileTime,
        );

        // Assert
        expect(flag, isA<FeatureFlag>());
        // Fields are final, cannot be modified
      });

      test('should allow instances in collections', () {
        // Arrange
        const flags = [
          FeatureFlag(
            key: 'flag1',
            value: true,
            source: FeatureFlagSource.compileTime,
          ),
          FeatureFlag(
            key: 'flag2',
            value: false,
            source: FeatureFlagSource.remoteConfig,
          ),
        ];

        // Act & Assert
        expect(flags.length, 2);
        expect(flags[0].key, 'flag1');
        expect(flags[1].key, 'flag2');
      });
    });
  });
}
