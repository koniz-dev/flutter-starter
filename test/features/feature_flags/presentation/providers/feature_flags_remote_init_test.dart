import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A remote source that, like a real remote-config SDK, only serves values
/// once it has been initialized and has fetched - on this same instance.
class _StatefulRemote implements FeatureFlagsRemoteDataSource {
  _StatefulRemote(this.stats, {this.failInit = false}) {
    stats.instances++;
  }

  final _Stats stats;
  final bool failInit;
  bool _ready = false;

  @override
  Future<void> initialize() async {
    stats.initializes++;
    if (failInit) throw Exception('remote config unreachable');
  }

  @override
  Future<void> fetchAndActivate() async {
    stats.fetches++;
    _ready = true;
  }

  @override
  Future<bool?> getRemoteFlag(String key) async =>
      _ready && key == FeatureFlags.newFeature.value ? true : null;

  @override
  Future<Map<String, bool>> getAllRemoteFlags() async =>
      _ready ? {FeatureFlags.newFeature.value: true} : {};

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {}
}

class _Stats {
  int instances = 0;
  int initializes = 0;
  int fetches = 0;
}

class _RecordingLoggingService extends LoggingService {
  _RecordingLoggingService() : super(enableLogging: false);

  final List<String> warnings = [];

  @override
  void warning(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => warnings.add(message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Stats stats;
  late _RecordingLoggingService logger;

  ProviderContainer containerWith({bool failInit = false}) {
    final container = ProviderContainer(
      overrides: [
        featureFlagsRemoteDataSourceProvider.overrideWith(
          (ref) => _StatefulRemote(stats, failInit: failInit),
        ),
        loggingServiceProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Lets auto-disposed providers that nothing listens to be disposed, as
  /// they are between two reads in the running app.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    stats = _Stats();
    logger = _RecordingLoggingService();
  });

  group('an overridden remote flag source', () {
    test('serves its value to the first flag read, with no manual '
        'initialization', () async {
      final container = containerWith();

      final enabled = await container.read(
        isFeatureEnabledProvider(FeatureFlags.newFeature).future,
      );

      expect(enabled, isTrue);
      expect(stats.initializes, 1);
      expect(stats.fetches, 1);
    });

    test('is built and initialized once across many reads', () async {
      final container = containerWith();

      for (var i = 0; i < 3; i++) {
        expect(
          await container.read(
            isFeatureEnabledProvider(FeatureFlags.newFeature).future,
          ),
          isTrue,
        );
        await settle();
        final flag = await container.read(
          featureFlagProvider(FeatureFlags.newFeature).future,
        );
        expect(flag?.source, FeatureFlagSource.remoteConfig);
        await settle();
        final all = await container.read(allFeatureFlagsProvider.future);
        expect(all[FeatureFlags.newFeature.value]?.value, isTrue);
        await settle();
      }

      expect(stats.instances, 1);
      expect(stats.initializes, 1);
      expect(stats.fetches, 1);
    });

    test('is the instance a manual refresh fetches again', () async {
      final container = containerWith();
      await container.read(
        isFeatureEnabledProvider(FeatureFlags.newFeature).future,
      );
      await settle();

      await container.read(featureFlagsManagerProvider).refresh();

      expect(stats.instances, 1);
      expect(stats.fetches, 2);
    });

    test('that fails to initialize is logged, and flags fall back to their '
        'defaults', () async {
      final container = containerWith(failInit: true);

      final enabled = await container.read(
        isFeatureEnabledProvider(FeatureFlags.newFeature).future,
      );

      expect(enabled, FeatureFlags.newFeature.defaultValue);
      expect(logger.warnings, hasLength(1));
      expect(logger.warnings.single, contains('Remote feature flags'));
    });
  });
}
