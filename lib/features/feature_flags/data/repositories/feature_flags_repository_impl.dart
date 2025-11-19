import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/services/local_feature_flags_service.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';

/// Implementation of [FeatureFlagsRepository]
class FeatureFlagsRepositoryImpl implements FeatureFlagsRepository {
  /// Creates a [FeatureFlagsRepositoryImpl] with the given
  /// [remoteDataSource] and [localDataSource]
  FeatureFlagsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Remote data source for fetching flags from Firebase Remote Config
  final FeatureFlagsRemoteDataSource remoteDataSource;

  /// Local data source for storing and retrieving local overrides
  final FeatureFlagsLocalDataSource localDataSource;

  @override
  Future<Result<FeatureFlag>> getFlag(String key) async {
    try {
      // Priority 1: Local override (highest priority)
      final localOverride = await localDataSource.getLocalOverride(key);
      if (localOverride != null) {
        return Success(
          FeatureFlag(
            key: key,
            value: localOverride,
            source: FeatureFlagSource.localOverride,
            lastUpdated: DateTime.now(),
          ),
        );
      }

      // Priority 2: Remote config
      final remoteValue = await remoteDataSource.getRemoteFlag(key);
      if (remoteValue != null) {
        return Success(
          FeatureFlag(
            key: key,
            value: remoteValue,
            source: FeatureFlagSource.remoteConfig,
            lastUpdated: DateTime.now(),
          ),
        );
      }

      // Priority 3: Local flags (environment, build mode, compile-time)
      final localFlag = LocalFeatureFlagsService.instance.getLocalFlag(key);
      if (localFlag != null) {
        return Success(localFlag);
      }

      // Flag not found
      return ResultFailure(
        NotFoundFailure('Feature flag not found: $key'),
      );
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<Map<String, FeatureFlag>>> getFlags(List<String> keys) async {
    try {
      final flags = <String, FeatureFlag>{};
      for (final key in keys) {
        final result = await getFlag(key);
        result.when(
          success: (FeatureFlag flag) => flags[flag.key] = flag,
          failureCallback: (Failure _) {
            // Skip flags that don't exist
          },
        );
      }
      return Success(flags);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<Map<String, FeatureFlag>>> getAllFlags() async {
    try {
      final flags = <String, FeatureFlag>{};

      // Get local overrides
      final localOverrides = await localDataSource.getAllLocalOverrides();
      for (final entry in localOverrides.entries) {
        flags[entry.key] = FeatureFlag(
          key: entry.key,
          value: entry.value,
          source: FeatureFlagSource.localOverride,
          lastUpdated: DateTime.now(),
        );
      }

      // Get remote flags
      final remoteFlags = await remoteDataSource.getAllRemoteFlags();
      for (final entry in remoteFlags.entries) {
        // Only add if not already in flags (local override takes precedence)
        if (!flags.containsKey(entry.key)) {
          flags[entry.key] = FeatureFlag(
            key: entry.key,
            value: entry.value,
            source: FeatureFlagSource.remoteConfig,
            lastUpdated: DateTime.now(),
          );
        }
      }

      // Get local flags
      final localFlags = LocalFeatureFlagsService.instance.getAllLocalFlags();
      for (final entry in localFlags.entries) {
        // Only add if not already in flags (higher priority sources take
        // precedence)
        if (!flags.containsKey(entry.key)) {
          flags[entry.key] = entry.value;
        }
      }

      return Success(flags);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<void>> refreshRemoteFlags() async {
    try {
      await remoteDataSource.fetchAndActivate();
      return const Success(null);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<void>> setLocalOverride(
    String key, {
    required bool value,
  }) async {
    try {
      await localDataSource.setLocalOverride(key, value: value);
      return const Success(null);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<void>> clearLocalOverride(String key) async {
    try {
      await localDataSource.clearLocalOverride(key);
      return const Success(null);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<void>> clearAllLocalOverrides() async {
    try {
      await localDataSource.clearAllLocalOverrides();
      return const Success(null);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<bool>> isEnabled(String key) async {
    try {
      final result = await getFlag(key);
      return result.map((FeatureFlag flag) => flag.value);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<void>> initialize() async {
    try {
      await remoteDataSource.initialize();
      await remoteDataSource.fetchAndActivate();
      return const Success(null);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }
}
