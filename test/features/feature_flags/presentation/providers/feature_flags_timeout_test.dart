import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_local_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/datasources/feature_flags_remote_datasource.dart';
import 'package:flutter_starter/features/feature_flags/data/repositories/feature_flags_repository_impl.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/features/feature_flags/presentation/widgets/feature_flag_builder.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _HeldRemote implements FeatureFlagsRemoteDataSource {
  Completer<void> gate = Completer<void>();
  bool fail = false;
  bool failFetch = false;
  Completer<void>? fetchGate;
  int initializes = 0;
  int fetches = 0;
  int reads = 0;
  bool ready = false;

  @override
  Future<void> initialize() async {
    initializes++;
    if (fail) throw StateError('unavailable');
    await gate.future;
  }

  @override
  Future<void> fetchAndActivate() async {
    fetches++;
    await fetchGate?.future;
    if (failFetch) throw StateError('fetch unavailable');
    ready = true;
  }

  @override
  Future<bool?> getRemoteFlag(String key) async {
    reads++;
    if (!ready) throw StateError('read before initialization');
    return true;
  }

  @override
  Future<Map<String, bool>> getAllRemoteFlags() async {
    reads++;
    if (!ready) throw StateError('read before initialization');
    return {FeatureFlags.newFeature.value: true};
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _HeldRemote remote;
  late FeatureFlagsRepositoryImpl repository;
  late ProviderContainer container;

  void configure({Duration timeout = const Duration(milliseconds: 50)}) {
    repository = FeatureFlagsRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: FeatureFlagsLocalDataSourceImpl(
        storageService: InMemoryKeyValueStore(),
      ),
      remoteTimeout: timeout,
    );
    container = ProviderContainer(
      overrides: [
        featureFlagsRepositoryProvider.overrideWithValue(repository),
        loggingServiceProvider.overrideWithValue(
          LoggingService(enableLogging: false),
        ),
      ],
    );
  }

  setUp(() {
    remote = _HeldRemote();
    configure();
  });
  tearDown(() => container.dispose());

  for (final fails in [false, true]) {
    test(
      'flag providers settle locally after ${fails ? 'failure' : 'timeout'}',
      () async {
        remote.fail = fails;
        await repository.setLocalOverride('local_override', value: true);
        final enabled = container.read(
          isFeatureEnabledProvider(FeatureFlags.newFeature).future,
        );
        final flag = container.read(
          featureFlagProvider(FeatureFlags.debugMenu).future,
        );
        final all = container.read(allFeatureFlagsProvider.future);
        expect(
          await enabled.timeout(const Duration(milliseconds: 500)),
          FeatureFlags.newFeature.defaultValue,
        );
        expect(
          (await flag.timeout(const Duration(milliseconds: 500)))?.source,
          FeatureFlagSource.buildMode,
        );
        final flags = await all.timeout(const Duration(milliseconds: 500));
        expect(flags['local_override']?.value, isTrue);
        expect(flags[FeatureFlags.debugMenu.value]?.value, isTrue);
        expect(
          flags[FeatureFlags.newFeature.value]?.value,
          FeatureFlags.newFeature.defaultValue,
        );
        expect(remote.reads, 0);
        expect(remote.initializes, 1);
        remote.gate.complete();
        await pumpEventQueue();
        expect(
          remote.fetches,
          0,
          reason: 'a late initializer cannot start fetching',
        );
        expect(
          (await repository.getAllFlags()).dataOrNull?['local_override']?.value,
          isTrue,
        );
        expect(remote.reads, 0);
      },
    );
  }

  test(
    'refresh after timeout retries initialization and restores remote reads',
    () async {
      expect((await repository.initialize()).isFailure, isTrue);
      remote.gate.complete();
      await pumpEventQueue();
      expect((await repository.refreshRemoteFlags()).isSuccess, isTrue);
      expect(remote.initializes, 2);
      expect(remote.fetches, 1);
      expect(
        (await repository.getFlag('remote')).dataOrNull?.source,
        FeatureFlagSource.remoteConfig,
      );
      expect((await repository.refreshRemoteFlags()).isSuccess, isTrue);
      expect(remote.initializes, 2);
      expect(remote.fetches, 2);
    },
  );

  Future<void> expectActivatedValues() async {
    final flag = (await repository.getFlag(FeatureFlags.newFeature.value))
        .dataOrNull;
    expect(flag?.value, isTrue);
    expect(flag?.source, FeatureFlagSource.remoteConfig);
    final all = (await repository.getAllFlags()).dataOrNull;
    expect(all?[FeatureFlags.newFeature.value]?.value, isTrue);
    expect(
      all?[FeatureFlags.newFeature.value]?.source,
      FeatureFlagSource.remoteConfig,
    );
  }

  test('activated remote values remain readable during a refresh', () async {
    remote.gate.complete();
    expect((await repository.initialize()).isSuccess, isTrue);
    await expectActivatedValues();
    final gate = remote.fetchGate = Completer<void>();
    final refresh = repository.refreshRemoteFlags();
    try {
      await pumpEventQueue();
      await expectActivatedValues();
    } finally {
      gate.complete();
      expect((await refresh).isSuccess, isTrue);
    }
    await expectActivatedValues();
  });

  test('a failed refresh retains the activated remote values', () async {
    remote.gate.complete();
    expect((await repository.initialize()).isSuccess, isTrue);
    remote.failFetch = true;
    expect((await repository.refreshRemoteFlags()).isFailure, isTrue);
    await expectActivatedValues();
  });

  test('a timed-out refresh retains the activated remote values', () async {
    remote.gate.complete();
    expect((await repository.initialize()).isSuccess, isTrue);
    final gate = remote.fetchGate = Completer<void>();
    try {
      expect((await repository.refreshRemoteFlags()).isFailure, isTrue);
      await expectActivatedValues();
      expect((await repository.refreshRemoteFlags()).isFailure, isTrue);
      expect(remote.fetches, 2, reason: 'do not overlap a held vendor fetch');
    } finally {
      gate.complete();
      await pumpEventQueue();
    }
    await expectActivatedValues();
  });

  test('timed-out fetch cannot overlap a newer activation', () async {
    remote.gate.complete();
    remote.fetchGate = Completer<void>();
    expect(
      (await repository.initialize().timeout(const Duration(milliseconds: 500)))
          .isFailure,
      isTrue,
    );
    expect(remote.fetches, 1);
    expect((await repository.refreshRemoteFlags()).isFailure, isTrue);
    expect(remote.initializes, 1);
    expect(remote.fetches, 1);
    remote.fetchGate!.complete();
    await pumpEventQueue();
    expect((await repository.getFlag('remote')).isFailure, isTrue);
    expect(
      remote.reads,
      0,
      reason: 'late SDK completion cannot re-enable reads',
    );
    expect((await repository.refreshRemoteFlags()).isSuccess, isTrue);
    expect(remote.initializes, 2);
    expect(remote.fetches, 2);
    expect(
      (await repository.getFlag('remote')).dataOrNull?.source,
      FeatureFlagSource.remoteConfig,
    );
  });

  testWidgets(
    'FeatureFlagBuilder stops spinning when initialization times out',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: FeatureFlagBuilder(
              flag: FeatureFlags.newFeature,
              enabledBuilder: (_) => const Text('enabled'),
              disabledBuilder: (_) => const Text('local default'),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('local default'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(remote.reads, 0);
    },
  );

  testWidgets('debug refresh waits for held initialization before fetching', (
    tester,
  ) async {
    container.dispose();
    remote = _HeldRemote();
    configure(timeout: const Duration(seconds: 5));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeatureFlagsDebugScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(remote.initializes, 1);
    expect(remote.fetches, 0);
    remote.gate.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(remote.initializes, 1);
    expect(remote.fetches, 2);
    expect(tester.takeException(), isNull);
  });
}
