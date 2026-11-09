import 'dart:async';

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
    this.remoteTimeout = const Duration(seconds: 10),
  });

  /// Remote data source for fetching flags from Firebase Remote Config
  final FeatureFlagsRemoteDataSource remoteDataSource;

  /// Local data source for storing and retrieving local overrides
  final FeatureFlagsLocalDataSource localDataSource;

  /// Upper bound for each remote initialization or refresh attempt.
  final Duration remoteTimeout;

  // Direct repository callers may supply an already initialized source.
  // Failed initializations stay local; a refresh keeps activated SDK values.
  bool _remoteAvailable = true;
  Future<Result<void>>? _remoteOperation;
  Future<void>? _sdkOperation;
  int _remoteGeneration = 0;

  Future<Result<void>> _updateRemote({required bool initialize}) {
    if (_remoteOperation != null) return _remoteOperation!;
    // A timeout cannot cancel a vendor SDK fetch. Do not overlap another
    // activation with it: the older fetch could overwrite the newer cache.
    if (_sdkOperation != null) {
      return Future.value(
        const ResultFailure(
          NetworkFailure('Remote feature flags update is still in progress'),
        ),
      );
    }
    final generation = ++_remoteGeneration;
    if (initialize) _remoteAvailable = false;
    _remoteOperation =
        _runRemote(initialize: initialize, generation: generation).whenComplete(
          () {
            _remoteOperation = null;
          },
        );
    return _remoteOperation!;
  }

  Future<Result<void>> _runRemote({
    required bool initialize,
    required int generation,
  }) async {
    try {
      final operation = (() async {
        if (initialize) await remoteDataSource.initialize();
        // A timed-out initialization cannot start a late fetch while a
        // newer attempt is running. SDK futures themselves are not cancelable.
        if (generation != _remoteGeneration) return;
        await remoteDataSource.fetchAndActivate();
      })();
      _sdkOperation = operation;
      void settled() {
        if (identical(_sdkOperation, operation)) _sdkOperation = null;
      }

      // Consume late errors as well as success, without re-enabling reads.
      unawaited(
        operation.then<void>(
          (_) => settled(),
          onError: (Object error, StackTrace trace) {
            settled();
          },
        ),
      );
      await operation.timeout(remoteTimeout);
      _remoteAvailable = true;
      return const Success(null);
    } on Object catch (error) {
      _remoteGeneration++;
      return ResultFailure(
        error is Exception
            ? ExceptionToFailureMapper.map(error)
            : UnknownFailure('Unexpected error: $error', code: 'UNKNOWN_ERROR'),
      );
    }
  }

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
      final remoteValue = _remoteAvailable
          ? await remoteDataSource.getRemoteFlag(key)
          : null;
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

      // Priority 3: Local flags (build mode, compile-time), resolved through
      // the flag's definition exactly as getAllFlags resolves them.
      final localFlag = LocalFeatureFlagsService.instance.getDefinedFlag(key);
      if (localFlag != null) {
        return Success(localFlag);
      }

      // Flag not found
      return ResultFailure(NotFoundFailure('Feature flag not found: $key'));
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
          success: (flag) => flags[flag.key] = flag,
          failureCallback: (failure) {
            // Skip flags that don't exist (NotFoundFailure)
            // But fail on other exceptions
            if (failure is! NotFoundFailure) {
              throw Exception('Failed to get flag $key: ${failure.message}');
            }
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
      final remoteFlags = _remoteAvailable
          ? await remoteDataSource.getAllRemoteFlags()
          : <String, bool>{};
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
  Future<Result<void>> refreshRemoteFlags() =>
      _updateRemote(initialize: !_remoteAvailable);

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
      return result.map((flag) => flag.value);
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    } on Object catch (e) {
      return ResultFailure(
        UnknownFailure('Unexpected error: $e', code: 'UNKNOWN_ERROR'),
      );
    }
  }

  @override
  Future<Result<void>> initialize() => _updateRemote(initialize: true);
}
