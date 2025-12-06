import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFeatureFlagsRepository extends Mock
    implements FeatureFlagsRepository {}

void main() {
  group('FeatureFlagsManager', () {
    late MockFeatureFlagsRepository mockRepository;
    late FeatureFlagsManager manager;

    setUp(() {
      mockRepository = MockFeatureFlagsRepository();
      manager = FeatureFlagsManager(mockRepository);
    });

    group('isEnabled', () {
      test('should return true when flag is enabled', () async {
        // Arrange
        final flag = FeatureFlag(
          key: FeatureFlags.newFeature.value,
          value: true,
          source: FeatureFlagSource.remoteConfig,
        );
        when(
          () => mockRepository.getFlag(any()),
        ).thenAnswer((_) async => Success(flag));

        // Act
        final result = await manager.isEnabled(FeatureFlags.newFeature);

        // Assert
        expect(result, isTrue);
        verify(
          () => mockRepository.getFlag(FeatureFlags.newFeature.value),
        ).called(1);
      });

      test('should return false when flag is disabled', () async {
        // Arrange
        final flag = FeatureFlag(
          key: FeatureFlags.newFeature.value,
          value: false,
          source: FeatureFlagSource.remoteConfig,
        );
        when(
          () => mockRepository.getFlag(any()),
        ).thenAnswer((_) async => Success(flag));

        // Act
        final result = await manager.isEnabled(FeatureFlags.newFeature);

        // Assert
        expect(result, isFalse);
      });

      test('should return defaultValue when repository fails', () async {
        // Arrange
        const failure = CacheFailure('Failed to get flag');
        const resultFailure = ResultFailure<FeatureFlag>(failure);
        when(
          () => mockRepository.getFlag(any()),
        ).thenAnswer((_) async => resultFailure);

        // Act
        final result = await manager.isEnabled(FeatureFlags.newFeature);

        // Assert
        expect(result, FeatureFlags.newFeature.defaultValue);
        expect(result, isFalse);
      });

      test('should return defaultValue for different flags', () async {
        // Arrange
        const failure = CacheFailure('Failed to get flag');
        const resultFailure = ResultFailure<FeatureFlag>(failure);
        when(
          () => mockRepository.getFlag(any()),
        ).thenAnswer((_) async => resultFailure);

        // Act
        final darkModeResult = await manager.isEnabled(FeatureFlags.darkMode);
        final analyticsResult = await manager.isEnabled(FeatureFlags.analytics);

        // Assert
        expect(darkModeResult, FeatureFlags.darkMode.defaultValue);
        expect(analyticsResult, FeatureFlags.analytics.defaultValue);
        expect(darkModeResult, isTrue);
        expect(analyticsResult, isTrue);
      });
    });

    group('getFlag', () {
      test('should return flag when repository succeeds', () async {
        // Arrange
        final flag = FeatureFlag(
          key: FeatureFlags.newFeature.value,
          value: true,
          source: FeatureFlagSource.remoteConfig,
          description: 'Test flag',
        );
        when(
          () => mockRepository.getFlag(any()),
        ).thenAnswer((_) async => Success(flag));

        // Act
        final result = await manager.getFlag(FeatureFlags.newFeature);

        // Assert
        expect(result, isNotNull);
        expect(result?.key, FeatureFlags.newFeature.value);
        expect(result?.value, isTrue);
        expect(result?.description, 'Test flag');
      });

      test('should return null when repository fails', () async {
        // Arrange
        const failure = CacheFailure('Failed to get flag');
        const resultFailure = ResultFailure<FeatureFlag>(failure);
        when(
          () => mockRepository.getFlag(any()),
        ).thenAnswer((_) async => resultFailure);

        // Act
        final result = await manager.getFlag(FeatureFlags.newFeature);

        // Assert
        expect(result, isNull);
      });

      test('should return flag with different sources', () async {
        // Arrange
        final remoteFlag = FeatureFlag(
          key: FeatureFlags.newFeature.value,
          value: true,
          source: FeatureFlagSource.remoteConfig,
        );
        final localFlag = FeatureFlag(
          key: FeatureFlags.darkMode.value,
          value: false,
          source: FeatureFlagSource.localOverride,
        );
        when(
          () => mockRepository.getFlag(FeatureFlags.newFeature.value),
        ).thenAnswer((_) async => Success(remoteFlag));
        when(
          () => mockRepository.getFlag(FeatureFlags.darkMode.value),
        ).thenAnswer((_) async => Success(localFlag));

        // Act
        final remoteResult = await manager.getFlag(FeatureFlags.newFeature);
        final localResult = await manager.getFlag(FeatureFlags.darkMode);

        // Assert
        expect(remoteResult?.source, FeatureFlagSource.remoteConfig);
        expect(localResult?.source, FeatureFlagSource.localOverride);
      });
    });

    group('getFlags', () {
      test('should return map of flags when repository succeeds', () async {
        // Arrange
        final flags = {
          FeatureFlags.newFeature.value: FeatureFlag(
            key: FeatureFlags.newFeature.value,
            value: true,
            source: FeatureFlagSource.remoteConfig,
          ),
          FeatureFlags.darkMode.value: FeatureFlag(
            key: FeatureFlags.darkMode.value,
            value: false,
            source: FeatureFlagSource.remoteConfig,
          ),
        };
        when(
          () => mockRepository.getFlags(any()),
        ).thenAnswer((_) async => Success(flags));

        // Act
        final result = await manager.getFlags([
          FeatureFlags.newFeature,
          FeatureFlags.darkMode,
        ]);

        // Assert
        expect(result, isA<Map<String, bool>>());
        expect(result.length, 2);
        expect(result[FeatureFlags.newFeature.value], isTrue);
        expect(result[FeatureFlags.darkMode.value], isFalse);
      });

      test('should return empty map when repository fails', () async {
        // Arrange
        const failure = CacheFailure('Failed to get flags');
        const resultFailure = ResultFailure<Map<String, FeatureFlag>>(failure);
        when(
          () => mockRepository.getFlags(any()),
        ).thenAnswer((_) async => resultFailure);

        // Act
        final result = await manager.getFlags([
          FeatureFlags.newFeature,
          FeatureFlags.darkMode,
        ]);

        // Assert
        expect(result, isA<Map<String, bool>>());
        expect(result, isEmpty);
      });

      test('should handle empty list of keys', () async {
        // Arrange
        const emptyFlags = <String, FeatureFlag>{};
        const success = Success<Map<String, FeatureFlag>>(emptyFlags);
        when(
          () => mockRepository.getFlags(any()),
        ).thenAnswer((_) async => success);

        // Act
        final result = await manager.getFlags([]);

        // Assert
        expect(result, isA<Map<String, bool>>());
        expect(result, isEmpty);
      });

      test('should handle multiple flags with different values', () async {
        // Arrange
        final flags = {
          FeatureFlags.newFeature.value: FeatureFlag(
            key: FeatureFlags.newFeature.value,
            value: true,
            source: FeatureFlagSource.remoteConfig,
          ),
          FeatureFlags.premiumFeatures.value: FeatureFlag(
            key: FeatureFlags.premiumFeatures.value,
            value: false,
            source: FeatureFlagSource.remoteConfig,
          ),
          FeatureFlags.analytics.value: FeatureFlag(
            key: FeatureFlags.analytics.value,
            value: true,
            source: FeatureFlagSource.remoteConfig,
          ),
        };
        when(
          () => mockRepository.getFlags(any()),
        ).thenAnswer((_) async => Success(flags));

        // Act
        final result = await manager.getFlags([
          FeatureFlags.newFeature,
          FeatureFlags.premiumFeatures,
          FeatureFlags.analytics,
        ]);

        // Assert
        expect(result.length, 3);
        expect(result[FeatureFlags.newFeature.value], isTrue);
        expect(result[FeatureFlags.premiumFeatures.value], isFalse);
        expect(result[FeatureFlags.analytics.value], isTrue);
      });
    });

    group('refresh', () {
      test('should call repository refreshRemoteFlags', () async {
        // Arrange
        when(
          () => mockRepository.refreshRemoteFlags(),
        ).thenAnswer((_) async => const Success<void>(null));

        // Act
        await manager.refresh();

        // Assert
        verify(() => mockRepository.refreshRemoteFlags()).called(1);
      });

      test('should handle refresh failure gracefully', () async {
        // Arrange
        const failure = NetworkFailure('Network error');
        const resultFailure = ResultFailure<void>(failure);
        when(
          () => mockRepository.refreshRemoteFlags(),
        ).thenAnswer((_) async => resultFailure);

        // Act & Assert
        await expectLater(manager.refresh(), completes);
        verify(() => mockRepository.refreshRemoteFlags()).called(1);
      });
    });

    group('setLocalOverride', () {
      test(
        'should call repository setLocalOverride with correct parameters',
        () async {
          // Arrange
          when(
            () => mockRepository.setLocalOverride(
              any(),
              value: any(named: 'value'),
            ),
          ).thenAnswer((_) async => const Success<void>(null));

          // Act
          await manager.setLocalOverride(
            FeatureFlags.newFeature,
            value: true,
          );

          // Assert
          verify(
            () => mockRepository.setLocalOverride(
              FeatureFlags.newFeature.value,
              value: true,
            ),
          ).called(1);
        },
      );

      test('should handle setLocalOverride failure gracefully', () async {
        // Arrange
        const failure = CacheFailure('Failed to set override');
        const resultFailure = ResultFailure<void>(failure);
        when(
          () => mockRepository.setLocalOverride(
            any(),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async => resultFailure);

        // Act & Assert
        await expectLater(
          manager.setLocalOverride(FeatureFlags.newFeature, value: false),
          completes,
        );
      });
    });

    group('clearLocalOverride', () {
      test('should call repository clearLocalOverride', () async {
        // Arrange
        when(
          () => mockRepository.clearLocalOverride(any()),
        ).thenAnswer((_) async => const Success<void>(null));

        // Act
        await manager.clearLocalOverride(FeatureFlags.newFeature);

        // Assert
        verify(
          () =>
              mockRepository.clearLocalOverride(FeatureFlags.newFeature.value),
        ).called(1);
      });

      test('should handle clearLocalOverride failure gracefully', () async {
        // Arrange
        const failure = CacheFailure('Failed to clear override');
        const resultFailure = ResultFailure<void>(failure);
        when(
          () => mockRepository.clearLocalOverride(any()),
        ).thenAnswer((_) async => resultFailure);

        // Act & Assert
        await expectLater(
          manager.clearLocalOverride(FeatureFlags.newFeature),
          completes,
        );
      });
    });

    group('clearAllLocalOverrides', () {
      test('should call repository clearAllLocalOverrides', () async {
        // Arrange
        when(
          () => mockRepository.clearAllLocalOverrides(),
        ).thenAnswer((_) async => const Success<void>(null));

        // Act
        await manager.clearAllLocalOverrides();

        // Assert
        verify(() => mockRepository.clearAllLocalOverrides()).called(1);
      });

      test('should handle clearAllLocalOverrides failure gracefully', () async {
        // Arrange
        const failure = CacheFailure('Failed to clear overrides');
        const resultFailure = ResultFailure<void>(failure);
        when(
          () => mockRepository.clearAllLocalOverrides(),
        ).thenAnswer((_) async => resultFailure);

        // Act & Assert
        await expectLater(manager.clearAllLocalOverrides(), completes);
      });
    });

    group('Edge Cases', () {
      test('should handle multiple consecutive calls', () async {
        // Arrange
        final flag = FeatureFlag(
          key: FeatureFlags.newFeature.value,
          value: true,
          source: FeatureFlagSource.remoteConfig,
        );
        when(
          () => mockRepository.getFlag(any()),
        ).thenAnswer((_) async => Success(flag));

        // Act
        final result1 = await manager.isEnabled(FeatureFlags.newFeature);
        final result2 = await manager.isEnabled(FeatureFlags.newFeature);
        final result3 = await manager.isEnabled(FeatureFlags.newFeature);

        // Assert
        expect(result1, isTrue);
        expect(result2, isTrue);
        expect(result3, isTrue);
        verify(
          () => mockRepository.getFlag(FeatureFlags.newFeature.value),
        ).called(3);
      });

      test('should handle different flag keys correctly', () async {
        // Arrange
        final flag1 = FeatureFlag(
          key: FeatureFlags.newFeature.value,
          value: true,
          source: FeatureFlagSource.remoteConfig,
        );
        final flag2 = FeatureFlag(
          key: FeatureFlags.darkMode.value,
          value: false,
          source: FeatureFlagSource.remoteConfig,
        );
        when(
          () => mockRepository.getFlag(FeatureFlags.newFeature.value),
        ).thenAnswer((_) async => Success(flag1));
        when(
          () => mockRepository.getFlag(FeatureFlags.darkMode.value),
        ).thenAnswer((_) async => Success(flag2));

        // Act
        final result1 = await manager.isEnabled(FeatureFlags.newFeature);
        final result2 = await manager.isEnabled(FeatureFlags.darkMode);

        // Assert
        expect(result1, isTrue);
        expect(result2, isFalse);
      });
    });
  });

  group('FeatureFlagKey', () {
    test('should have correct properties', () {
      const key = FeatureFlagKey(
        value: 'test_key',
        defaultValue: true,
        description: 'Test description',
        category: 'Test',
      );

      expect(key.value, 'test_key');
      expect(key.defaultValue, isTrue);
      expect(key.description, 'Test description');
      expect(key.category, 'Test');
    });

    test('should be equal when values are equal', () {
      const key1 = FeatureFlagKey(
        value: 'test_key',
        defaultValue: true,
        description: 'Test',
      );
      const key2 = FeatureFlagKey(
        value: 'test_key',
        defaultValue: false,
        description: 'Different',
      );

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('should not be equal when values are different', () {
      const key1 = FeatureFlagKey(
        value: 'test_key1',
        defaultValue: true,
        description: 'Test',
      );
      const key2 = FeatureFlagKey(
        value: 'test_key2',
        defaultValue: true,
        description: 'Test',
      );

      expect(key1, isNot(equals(key2)));
    });

    test('should return value in toString', () {
      const key = FeatureFlagKey(
        value: 'test_key',
        defaultValue: true,
        description: 'Test',
      );

      expect(key.toString(), 'test_key');
    });
  });

  group('FeatureFlags', () {
    test('should have all feature flags defined', () {
      expect(FeatureFlags.all, isNotEmpty);
      expect(FeatureFlags.all.length, greaterThan(0));
    });

    test('should have correct flag properties', () {
      expect(FeatureFlags.newFeature.value, 'enable_new_feature');
      expect(FeatureFlags.newFeature.defaultValue, isFalse);
      expect(FeatureFlags.newFeature.description, isNotEmpty);

      expect(FeatureFlags.darkMode.value, 'enable_dark_mode');
      expect(FeatureFlags.darkMode.defaultValue, isTrue);
      expect(FeatureFlags.darkMode.description, isNotEmpty);
    });

    test('getByCategory should return flags in category', () {
      final features = FeatureFlags.getByCategory('Features');
      expect(features, isNotEmpty);
      expect(features, contains(FeatureFlags.newFeature));
      expect(features, contains(FeatureFlags.premiumFeatures));
      expect(features, contains(FeatureFlags.tasks));
    });

    test('getByCategory should return empty list for unknown category', () {
      final flags = FeatureFlags.getByCategory('UnknownCategory');
      expect(flags, isEmpty);
    });

    test('should have unique flag values', () {
      final values = FeatureFlags.all.map((flag) => flag.value).toList();
      expect(values.toSet().length, values.length);
    });
  });
}
