import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature Flags Providers', () {
    late ProviderContainer container;

    setUp(() {
      // Without a backing store every local-override read throws
      // MissingPluginException, which is what the old `catch`-everything
      // tests were papering over.
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Data Source Providers', () {
      test('featureFlagsLocalDataSourceProvider should provide '
          'FeatureFlagsLocalDataSource', () {
        final dataSource = container.read(featureFlagsLocalDataSourceProvider);
        expect(dataSource, isA<FeatureFlagsLocalDataSource>());
      });

      test('featureFlagsRemoteDataSourceProvider should provide '
          'FeatureFlagsRemoteDataSource', () {
        final dataSource = container.read(featureFlagsRemoteDataSourceProvider);
        expect(dataSource, isA<FeatureFlagsRemoteDataSource>());
      });
    });

    group('Repository Provider', () {
      test('featureFlagsRepositoryProvider should provide '
          'FeatureFlagsRepository', () {
        final repository = container.read(featureFlagsRepositoryProvider);
        expect(repository, isA<FeatureFlagsRepository>());
      });
    });

    group('Manager Provider', () {
      test(
        'featureFlagsManagerProvider should provide FeatureFlagsManager',
        () {
          final manager = container.read(featureFlagsManagerProvider);
          expect(manager, isNotNull);
        },
      );
    });

    group('Initialization Provider', () {
      test('featureFlagsInitializationProvider completes', () async {
        // Before #53 this was wrapped in `on Object catch (e) { expect(e,
        // isNotNull); }`, which turned any failure - including a failed
        // assertion - into a pass. With SharedPreferences mocked there is no
        // reason for it to fail, so the completion is asserted directly.
        await expectLater(
          container.read(featureFlagsInitializationProvider.future),
          completes,
        );
      }, timeout: const Timeout(Duration(seconds: 5)));
    });

    group('Feature Flag Providers', () {
      test(
        'isFeatureEnabledProvider falls back to the compile-time default',
        () async {
          // Nothing overrides `enable_new_feature`: no local override, the
          // remote source is the no-op one, and there is no FEATURE_* env var.
          // The manager must therefore hand back the key's own default.
          final enabled = await container.read(
            isFeatureEnabledProvider(FeatureFlags.newFeature).future,
          );

          expect(enabled, FeatureFlags.newFeature.defaultValue);
          expect(enabled, isFalse);
        },
        timeout: const Timeout(Duration(seconds: 5)),
      );

      test('isFeatureEnabledProvider honours a local override', () async {
        final repository = container.read(featureFlagsRepositoryProvider);
        await repository.setLocalOverride(
          FeatureFlags.newFeature.value,
          value: true,
        );

        final enabled = await container.read(
          isFeatureEnabledProvider(FeatureFlags.newFeature).future,
        );

        expect(
          enabled,
          isTrue,
          reason: 'a local override outranks the compile-time default',
        );
      }, timeout: const Timeout(Duration(seconds: 5)));

      test('featureFlagProvider returns null for an unset flag', () async {
        final flag = await container.read(
          featureFlagProvider(FeatureFlags.newFeature).future,
        );

        expect(flag, isNull);
      }, timeout: const Timeout(Duration(seconds: 5)));

      test('featureFlagProvider reports the overriding source', () async {
        final repository = container.read(featureFlagsRepositoryProvider);
        await repository.setLocalOverride(
          FeatureFlags.newFeature.value,
          value: true,
        );

        final flag = await container.read(
          featureFlagProvider(FeatureFlags.newFeature).future,
        );

        expect(flag, isNotNull);
        expect(flag!.value, isTrue);
        expect(flag.source, FeatureFlagSource.localOverride);
      }, timeout: const Timeout(Duration(seconds: 5)));

      test('allFeatureFlagsProvider exposes stored overrides', () async {
        final repository = container.read(featureFlagsRepositoryProvider);
        await repository.setLocalOverride(
          FeatureFlags.newFeature.value,
          value: true,
        );

        final flags = await container.read(allFeatureFlagsProvider.future);

        expect(flags.keys, contains(FeatureFlags.newFeature.value));
        expect(flags[FeatureFlags.newFeature.value]!.value, isTrue);
      }, timeout: const Timeout(Duration(seconds: 5)));

      test('allFeatureFlagsProvider returns an empty map on failure', () async {
        // The old version of this test never produced a failure, so the
        // failureCallback branch it claimed to cover never ran. Overriding the
        // repository with one that fails is what actually exercises it.
        final failingContainer = ProviderContainer(
          overrides: [
            featureFlagsRepositoryProvider.overrideWithValue(
              _FailingFeatureFlagsRepository(),
            ),
          ],
        );
        addTearDown(failingContainer.dispose);

        final flags = await failingContainer.read(
          allFeatureFlagsProvider.future,
        );

        expect(flags, isEmpty);
      }, timeout: const Timeout(Duration(seconds: 5)));
    });
  });
}

/// A repository whose reads always fail, so the `failureCallback` branches in
/// the providers are actually taken.
class _FailingFeatureFlagsRepository implements FeatureFlagsRepository {
  static const Failure _failure = UnknownFailure('flag store unavailable');

  @override
  Future<Result<void>> clearAllLocalOverrides() async =>
      const ResultFailure(_failure);

  @override
  Future<Result<void>> clearLocalOverride(String key) async =>
      const ResultFailure(_failure);

  @override
  Future<Result<Map<String, FeatureFlag>>> getAllFlags() async =>
      const ResultFailure(_failure);

  @override
  Future<Result<FeatureFlag>> getFlag(String key) async =>
      const ResultFailure(_failure);

  @override
  Future<Result<Map<String, FeatureFlag>>> getFlags(List<String> keys) async =>
      const ResultFailure(_failure);

  @override
  Future<Result<void>> initialize() async => const ResultFailure(_failure);

  @override
  Future<Result<bool>> isEnabled(String key) async =>
      const ResultFailure(_failure);

  @override
  Future<Result<void>> refreshRemoteFlags() async =>
      const ResultFailure(_failure);

  @override
  Future<Result<void>> setLocalOverride(
    String key, {
    required bool value,
  }) async => const ResultFailure(_failure);
}
