// Feature flags providers: docs in guides, not per-line here.
// ignore_for_file: public_member_api_docs

import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/repositories/feature_flags_repository_impl.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feature_flags_providers.g.dart';

// The data sources, repository and manager live as long as the container.
// A remote source is stateful - it is initialized and fetched once, then
// read - so an auto-disposed one would be rebuilt uninitialized on the next
// read, and every flag would quietly fall back to its local value.
@Riverpod(keepAlive: true)
FeatureFlagsLocalDataSource featureFlagsLocalDataSource(Ref ref) {
  final keyValueStore = ref.watch(keyValueStoreProvider);
  return FeatureFlagsLocalDataSourceImpl(storageService: keyValueStore);
}

@Riverpod(keepAlive: true)
FeatureFlagsRemoteDataSource featureFlagsRemoteDataSource(Ref ref) {
  return const NoOpFeatureFlagsRemoteDataSource();
}

@Riverpod(keepAlive: true)
FeatureFlagsRepository featureFlagsRepository(Ref ref) {
  final remoteDataSource = ref.watch(featureFlagsRemoteDataSourceProvider);
  final localDataSource = ref.watch(featureFlagsLocalDataSourceProvider);

  return FeatureFlagsRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
}

@Riverpod(keepAlive: true)
FeatureFlagsManager featureFlagsManager(Ref ref) {
  final repository = ref.watch(featureFlagsRepositoryProvider);
  return FeatureFlagsManager(repository);
}

/// Initializes and fetches the remote source once per container.
///
/// Every flag read awaits it, so the first read starts it and no read sees
/// the remote source before it is ready. It never fails: a remote that cannot
/// initialize is logged and the flags resolve from local values and defaults.
@Riverpod(keepAlive: true)
Future<void> featureFlagsInitialization(Ref ref) async {
  final repository = ref.watch(featureFlagsRepositoryProvider);
  Object? problem;
  StackTrace? stackTrace;
  try {
    problem = (await repository.initialize()).failureOrNull?.message;
  } on Object catch (error, trace) {
    // A repository other than the shipped one may throw instead of returning
    // a failure; that must not take every flag read down with it either.
    problem = error;
    stackTrace = trace;
  }
  if (problem != null) {
    ref
        .read(loggingServiceProvider)
        .warning(
          'Remote feature flags unavailable; using local values and defaults',
          context: {'failure': '$problem'},
          stackTrace: stackTrace,
        );
  }
}

@riverpod
Future<bool> isFeatureEnabled(Ref ref, FeatureFlagKey key) async {
  await ref.watch(featureFlagsInitializationProvider.future);
  final manager = ref.watch(featureFlagsManagerProvider);
  return await manager.isEnabled(key);
}

@riverpod
Future<FeatureFlag?> featureFlag(Ref ref, FeatureFlagKey key) async {
  await ref.watch(featureFlagsInitializationProvider.future);
  final manager = ref.watch(featureFlagsManagerProvider);
  return await manager.getFlag(key);
}

/// Every flag the repository knows, plus every [FeatureFlags.all] key.
///
/// A [FeatureFlags.all] key no source sets appears at its
/// [FeatureFlagKey.defaultValue] - the value [FeatureFlagsManager.isEnabled]
/// falls back to - so the debug screen can show and toggle the flags the app
/// actually gates on.
@riverpod
Future<Map<String, FeatureFlag?>> allFeatureFlags(Ref ref) async {
  await ref.watch(featureFlagsInitializationProvider.future);
  final repository = ref.watch(featureFlagsRepositoryProvider);
  final result = await repository.getAllFlags();
  return await result.when(
    success: (flags) => <String, FeatureFlag?>{
      for (final key in FeatureFlags.all)
        key.value: FeatureFlag(
          key: key.value,
          value: key.defaultValue,
          source: FeatureFlagSource.compileTime,
          description: key.description,
          defaultValue: key.defaultValue,
        ),
      ...flags,
    },
    // An error state, not an empty map: the debug screen then shows the
    // failure and its retry, rather than "no flags".
    failureCallback: Future<Map<String, FeatureFlag?>>.error,
  );
}
