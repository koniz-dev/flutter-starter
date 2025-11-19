import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/repositories/feature_flags_repository_impl.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';

// ============================================================================
// Feature Flags Data Source Providers
// ============================================================================

/// Provider for [FeatureFlagsLocalDataSource] instance
final featureFlagsLocalDataSourceProvider =
    Provider<FeatureFlagsLocalDataSource>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return FeatureFlagsLocalDataSourceImpl(storageService: storageService);
});

/// Provider for [FeatureFlagsRemoteDataSource] instance
final featureFlagsRemoteDataSourceProvider =
    Provider<FeatureFlagsRemoteDataSource>((ref) {
  // Default values for remote config
  // These will be used if Firebase Remote Config is not available
  final defaultValues = <String, dynamic>{
    // Add your default feature flag values here
    // Example: 'enable_new_feature': false,
  };
  return FeatureFlagsRemoteDataSourceImpl(defaultValues: defaultValues);
});

// ============================================================================
// Feature Flags Repository Provider
// ============================================================================

/// Provider for [FeatureFlagsRepository] instance
final featureFlagsRepositoryProvider = Provider<FeatureFlagsRepository>((ref) {
  final remoteDataSource = ref.watch(featureFlagsRemoteDataSourceProvider);
  final localDataSource = ref.watch(featureFlagsLocalDataSourceProvider);
  return FeatureFlagsRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

// ============================================================================
// Feature Flags Manager Provider
// ============================================================================

/// Provider for [FeatureFlagsManager] instance
final featureFlagsManagerProvider = Provider<FeatureFlagsManager>((ref) {
  final repository = ref.watch(featureFlagsRepositoryProvider);
  return FeatureFlagsManager(repository);
});

// ============================================================================
// Feature Flags Initialization Provider
// ============================================================================

/// Provider for initializing feature flags system
///
/// This should be awaited in the main function to ensure feature flags
/// are loaded before the app starts.
final featureFlagsInitializationProvider = FutureProvider<void>((ref) async {
  final repository = ref.read(featureFlagsRepositoryProvider);
  await repository.initialize();
});

// ============================================================================
// Individual Feature Flag Providers
// ============================================================================

/// Provider for checking if a feature flag is enabled
///
/// Usage:
/// ```dart
/// final isEnabled = ref.watch(
///   isFeatureEnabledProvider(FeatureFlags.newFeature),
/// );
/// ```
// ignore: specify_nonobvious_property_types
final isFeatureEnabledProvider = FutureProvider.family<bool, FeatureFlagKey>(
  (ref, FeatureFlagKey key) async {
    final manager = ref.watch(featureFlagsManagerProvider);
    return manager.isEnabled(key);
  },
);

/// Provider for getting a feature flag with full details
///
/// Usage:
/// ```dart
/// final flag = ref.watch(
///   featureFlagProvider(FeatureFlags.newFeature),
/// );
/// ```
// ignore: specify_nonobvious_property_types
final featureFlagProvider = FutureProvider.family<FeatureFlag?, FeatureFlagKey>(
  (ref, FeatureFlagKey key) async {
    final manager = ref.watch(featureFlagsManagerProvider);
    return manager.getFlag(key);
  },
);

/// Provider for getting all feature flags
final allFeatureFlagsProvider =
    FutureProvider<Map<String, FeatureFlag?>>((ref) async {
  final repository = ref.watch(featureFlagsRepositoryProvider);

  final result = await repository.getAllFlags();
  return result.when(
    success: (Map<String, FeatureFlag> flags) => flags,
    failureCallback: (Failure _) => <String, FeatureFlag?>{},
  );
});
