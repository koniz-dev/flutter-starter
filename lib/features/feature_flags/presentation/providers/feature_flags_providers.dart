// Feature flags providers: docs in guides, not per-line here.
// ignore_for_file: public_member_api_docs

import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/repositories/feature_flags_repository_impl.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feature_flags_providers.g.dart';

@riverpod
FeatureFlagsLocalDataSource featureFlagsLocalDataSource(Ref ref) {
  final storageService = ref.watch(storageServiceProvider);
  return FeatureFlagsLocalDataSourceImpl(storageService: storageService);
}

@riverpod
FeatureFlagsRemoteDataSource featureFlagsRemoteDataSource(Ref ref) {
  return const NoOpFeatureFlagsRemoteDataSource();
}

@riverpod
FeatureFlagsRepository featureFlagsRepository(Ref ref) {
  final remoteDataSource = ref.watch(featureFlagsRemoteDataSourceProvider);
  final localDataSource = ref.watch(featureFlagsLocalDataSourceProvider);

  return FeatureFlagsRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
}

@riverpod
FeatureFlagsManager featureFlagsManager(Ref ref) {
  final repository = ref.watch(featureFlagsRepositoryProvider);
  return FeatureFlagsManager(repository);
}

@riverpod
Future<void> featureFlagsInitialization(Ref ref) async {
  final repository = ref.read(featureFlagsRepositoryProvider);
  await repository.initialize();
}

@riverpod
Future<bool> isFeatureEnabled(Ref ref, FeatureFlagKey key) async {
  final manager = ref.watch(featureFlagsManagerProvider);
  return manager.isEnabled(key);
}

@riverpod
Future<FeatureFlag?> featureFlag(Ref ref, FeatureFlagKey key) async {
  final manager = ref.watch(featureFlagsManagerProvider);
  return manager.getFlag(key);
}

@riverpod
Future<Map<String, FeatureFlag?>> allFeatureFlags(Ref ref) async {
  final repository = ref.watch(featureFlagsRepositoryProvider);
  final result = await repository.getAllFlags();
  return result.when(
    success: (flags) => flags,
    failureCallback: (_) => <String, FeatureFlag?>{},
  );
}
