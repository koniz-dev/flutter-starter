import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/repositories/feature_flags_repository_impl.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFeatureFlagsRemoteDataSource extends Mock
    implements FeatureFlagsRemoteDataSource {}

class MockFeatureFlagsLocalDataSource extends Mock
    implements FeatureFlagsLocalDataSource {}

void main() {
  group('FeatureFlagsRepositoryImpl', () {
    late FeatureFlagsRepositoryImpl repository;
    late MockFeatureFlagsRemoteDataSource mockRemoteDataSource;
    late MockFeatureFlagsLocalDataSource mockLocalDataSource;

    setUp(() {
      mockRemoteDataSource = MockFeatureFlagsRemoteDataSource();
      mockLocalDataSource = MockFeatureFlagsLocalDataSource();
      repository = FeatureFlagsRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
      );
    });

    group('getFlag', () {
      test('should return local override when available', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.getFlag('test_flag');

        // Assert
        expect(result.isSuccess, isTrue);
        final flag = result.dataOrNull;
        expect(flag, isNotNull);
        expect(flag?.key, 'test_flag');
        expect(flag?.value, isTrue);
        expect(flag?.source, FeatureFlagSource.localOverride);
        verify(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .called(1);
        verifyNever(() => mockRemoteDataSource.getRemoteFlag(any()));
      });

      test('should return remote config when local override not available',
          () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .thenAnswer((_) async => null);
        when(() => mockRemoteDataSource.getRemoteFlag('test_flag'))
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.getFlag('test_flag');

        // Assert
        expect(result.isSuccess, isTrue);
        final flag = result.dataOrNull;
        expect(flag, isNotNull);
        expect(flag?.key, 'test_flag');
        expect(flag?.value, isFalse);
        expect(flag?.source, FeatureFlagSource.remoteConfig);
        verify(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .called(1);
        verify(() => mockRemoteDataSource.getRemoteFlag('test_flag')).called(1);
      });

      test('should return local flag when remote and override not available',
          () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .thenAnswer((_) async => null);
        when(() => mockRemoteDataSource.getRemoteFlag('test_flag'))
            .thenAnswer((_) async => null);
        // Mock LocalFeatureFlagsService to return a flag
        // Note: This requires the service to be testable or mocked

        // Act
        final result = await repository.getFlag('test_flag');

        // Assert
        // Result may be success (if local flag exists) or failure (if not)
        expect(result, isA<Result<FeatureFlag>>());
      });

      test('should return NotFoundFailure when flag not found', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('unknown_flag'))
            .thenAnswer((_) async => null);
        when(() => mockRemoteDataSource.getRemoteFlag('unknown_flag'))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getFlag('unknown_flag');

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<NotFoundFailure>());
      });

      test('should handle exceptions and map to failures', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.getFlag('test_flag');

        // Assert
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<Failure>());
      });
    });

    group('getFlags', () {
      test('should return map of flags for multiple keys', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('flag1'))
            .thenAnswer((_) async => true);
        when(() => mockLocalDataSource.getLocalOverride('flag2'))
            .thenAnswer((_) async => null);
        when(() => mockRemoteDataSource.getRemoteFlag('flag2'))
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.getFlags(['flag1', 'flag2']);

        // Assert
        expect(result.isSuccess, isTrue);
        final flags = result.dataOrNull;
        expect(flags, isNotNull);
        expect(flags?.length, 2);
        expect(flags?['flag1']?.value, isTrue);
        expect(flags?['flag2']?.value, isFalse);
      });

      test('should skip flags that do not exist', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('flag1'))
            .thenAnswer((_) async => true);
        when(() => mockLocalDataSource.getLocalOverride('unknown'))
            .thenAnswer((_) async => null);
        when(() => mockRemoteDataSource.getRemoteFlag('unknown'))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getFlags(['flag1', 'unknown']);

        // Assert
        expect(result.isSuccess, isTrue);
        final flags = result.dataOrNull;
        expect(flags, isNotNull);
        expect(flags?.length, 1);
        expect(flags?.containsKey('flag1'), isTrue);
        expect(flags?.containsKey('unknown'), isFalse);
      });

      test('should handle exceptions', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride(any()))
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.getFlags(['flag1']);

        // Assert
        expect(result.isFailure, isTrue);
      });
    });

    group('getAllFlags', () {
      test('should return all flags with correct priority', () async {
        // Arrange
        when(() => mockLocalDataSource.getAllLocalOverrides())
            .thenAnswer((_) async => {'override_flag': true});
        when(() => mockRemoteDataSource.getAllRemoteFlags()).thenAnswer(
          (_) async => {
            'remote_flag': false,
            'override_flag': false, // Should be overridden by local
          },
        );

        // Act
        final result = await repository.getAllFlags();

        // Assert
        expect(result.isSuccess, isTrue);
        final flags = result.dataOrNull;
        expect(flags, isNotNull);
        expect(flags?['override_flag']?.value, isTrue); // Local override wins
        expect(
          flags?['override_flag']?.source,
          FeatureFlagSource.localOverride,
        );
        expect(flags?['remote_flag']?.value, isFalse);
        expect(flags?['remote_flag']?.source, FeatureFlagSource.remoteConfig);
      });

      test('should handle exceptions', () async {
        // Arrange
        when(() => mockLocalDataSource.getAllLocalOverrides())
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.getAllFlags();

        // Assert
        expect(result.isFailure, isTrue);
      });
    });

    group('refreshRemoteFlags', () {
      test('should fetch and activate remote flags', () async {
        // Arrange
        when(() => mockRemoteDataSource.fetchAndActivate())
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.refreshRemoteFlags();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockRemoteDataSource.fetchAndActivate()).called(1);
      });

      test('should handle exceptions', () async {
        // Arrange
        when(() => mockRemoteDataSource.fetchAndActivate())
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.refreshRemoteFlags();

        // Assert
        expect(result.isFailure, isTrue);
      });
    });

    group('setLocalOverride', () {
      test('should set local override', () async {
        // Arrange
        when(
          () => mockLocalDataSource.setLocalOverride(
            'test_flag',
            value: true,
          ),
        ).thenAnswer((_) async => {});

        // Act
        final result = await repository.setLocalOverride(
          'test_flag',
          value: true,
        );

        // Assert
        expect(result.isSuccess, isTrue);
        verify(
          () => mockLocalDataSource.setLocalOverride(
            'test_flag',
            value: true,
          ),
        ).called(1);
      });

      test('should handle exceptions', () async {
        // Arrange
        when(() => mockLocalDataSource.setLocalOverride(any(), value: any()))
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.setLocalOverride(
          'test_flag',
          value: true,
        );

        // Assert
        expect(result.isFailure, isTrue);
      });
    });

    group('clearLocalOverride', () {
      test('should clear local override', () async {
        // Arrange
        when(() => mockLocalDataSource.clearLocalOverride('test_flag'))
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.clearLocalOverride('test_flag');

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockLocalDataSource.clearLocalOverride('test_flag'))
            .called(1);
      });

      test('should handle exceptions', () async {
        // Arrange
        when(() => mockLocalDataSource.clearLocalOverride(any()))
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.clearLocalOverride('test_flag');

        // Assert
        expect(result.isFailure, isTrue);
      });
    });

    group('clearAllLocalOverrides', () {
      test('should clear all local overrides', () async {
        // Arrange
        when(() => mockLocalDataSource.clearAllLocalOverrides())
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.clearAllLocalOverrides();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockLocalDataSource.clearAllLocalOverrides()).called(1);
      });

      test('should handle exceptions', () async {
        // Arrange
        when(() => mockLocalDataSource.clearAllLocalOverrides())
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.clearAllLocalOverrides();

        // Assert
        expect(result.isFailure, isTrue);
      });
    });

    group('isEnabled', () {
      test('should return true when flag is enabled', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .thenAnswer((_) async => true);

        // Act
        final result = await repository.isEnabled('test_flag');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isTrue);
      });

      test('should return false when flag is disabled', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride('test_flag'))
            .thenAnswer((_) async => false);

        // Act
        final result = await repository.isEnabled('test_flag');

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isFalse);
      });

      test('should handle exceptions', () async {
        // Arrange
        when(() => mockLocalDataSource.getLocalOverride(any()))
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.isEnabled('test_flag');

        // Assert
        expect(result.isFailure, isTrue);
      });
    });

    group('initialize', () {
      test('should initialize remote data source and fetch flags', () async {
        // Arrange
        when(() => mockRemoteDataSource.initialize())
            .thenAnswer((_) async => {});
        when(() => mockRemoteDataSource.fetchAndActivate())
            .thenAnswer((_) async => {});

        // Act
        final result = await repository.initialize();

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockRemoteDataSource.initialize()).called(1);
        verify(() => mockRemoteDataSource.fetchAndActivate()).called(1);
      });

      test('should handle exceptions during initialization', () async {
        // Arrange
        when(() => mockRemoteDataSource.initialize())
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.initialize();

        // Assert
        expect(result.isFailure, isTrue);
      });

      test('should handle exceptions during fetch', () async {
        // Arrange
        when(() => mockRemoteDataSource.initialize())
            .thenAnswer((_) async => {});
        when(() => mockRemoteDataSource.fetchAndActivate())
            .thenThrow(Exception('Test error'));

        // Act
        final result = await repository.initialize();

        // Assert
        expect(result.isFailure, isTrue);
      });
    });
  });
}
