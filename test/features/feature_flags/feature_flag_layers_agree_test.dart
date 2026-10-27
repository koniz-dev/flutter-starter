// The feature-flag layers must agree about one flag.
//
// `getFlag` used to read the local level without the flag's definition, so in
// a debug build `enable_debug_menu` was `true (buildMode)` on the debug screen
// and "not found", i.e. false, through `FeatureFlagsManager.isEnabled`. The
// screen listed only the local definitions, never the `FeatureFlags.all` keys
// the app gates on, and its toggle invalidated only `allFeatureFlagsProvider`,
// so a widget listening to `isFeatureEnabledProvider(key)` kept the old value.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  group('criterion 1: getFlag and getAllFlags agree', () {
    test('for enable_debug_menu', () async {
      expect(kDebugMode, isTrue, reason: 'flutter test runs in debug mode');
      final repository = container.read(featureFlagsRepositoryProvider);

      final single = (await repository.getFlag('enable_debug_menu')).dataOrNull;
      final all = (await repository.getAllFlags()).dataOrNull;

      expect(single, isNotNull, reason: 'getFlag must apply the definition');
      expect(single!.value, isTrue);
      expect(single.source, FeatureFlagSource.buildMode);
      expect(all!['enable_debug_menu']!.value, single.value);
      expect(all['enable_debug_menu']!.source, single.source);
    });

    test('for every local definition', () async {
      final repository = container.read(featureFlagsRepositoryProvider);
      final all = (await repository.getAllFlags()).dataOrNull!;

      for (final key in all.keys) {
        final single = (await repository.getFlag(key)).dataOrNull;
        expect(single?.value, all[key]!.value, reason: key);
        expect(single?.source, all[key]!.source, reason: key);
      }
    });

    test('the manager reads the debug-mode value', () async {
      final manager = container.read(featureFlagsManagerProvider);

      expect(await manager.isEnabled(FeatureFlags.debugMenu), isTrue);
    });
  });

  group('criterion 2: allFeatureFlagsProvider lists every key', () {
    test('every FeatureFlags.all key is present', () async {
      final flags = await container.read(allFeatureFlagsProvider.future);

      for (final key in FeatureFlags.all) {
        expect(flags.keys, contains(key.value));
      }
    });

    test('a key no source sets is at its FeatureFlagKey default', () async {
      final flags = await container.read(allFeatureFlagsProvider.future);
      final manager = container.read(featureFlagsManagerProvider);

      for (final key in FeatureFlags.all) {
        expect(
          flags[key.value]!.value,
          await manager.isEnabled(key),
          reason: '${key.value}: screen and manager must agree',
        );
      }
      // Two keys nothing else sets, one default on and one off.
      expect(flags[FeatureFlags.tasks.value]!.value, isTrue);
      expect(flags[FeatureFlags.newFeature.value]!.value, isFalse);
      expect(
        flags[FeatureFlags.newFeature.value]!.defaultValue,
        FeatureFlags.newFeature.defaultValue,
      );
    });

    test('a stored override still wins over the default', () async {
      await container
          .read(featureFlagsManagerProvider)
          .setLocalOverride(FeatureFlags.tasks, value: false);

      final flags = await container.read(allFeatureFlagsProvider.future);

      expect(flags[FeatureFlags.tasks.value]!.value, isFalse);
      expect(
        flags[FeatureFlags.tasks.value]!.source,
        FeatureFlagSource.localOverride,
      );
    });
  });

  group('criterion 3: the debug screen refreshes listened flags', () {
    Widget screen() => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeatureFlagsDebugScreen(),
      ),
    );

    Finder switchFor(FeatureFlagKey key) => find.descendant(
      of: find.ancestor(
        of: find.text(key.value),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(Switch),
    );

    Future<void> openCategory(WidgetTester tester, FeatureFlagKey key) async {
      await tester.tap(find.text(key.category!));
      await tester.pumpAndSettle();
    }

    testWidgets('a toggle reaches a listened isFeatureEnabledProvider', (
      tester,
    ) async {
      final seen = <bool>[];
      final sub = container.listen(
        isFeatureEnabledProvider(FeatureFlags.newFeature),
        (_, next) {
          if (next case AsyncData(:final value)) seen.add(value);
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(seen, [false]);

      await openCategory(tester, FeatureFlags.newFeature);
      await tester.tap(switchFor(FeatureFlags.newFeature));
      await tester.pumpAndSettle();

      expect(seen.last, isTrue, reason: 'the listener must see the toggle');
      expect(
        await container
            .read(featureFlagsManagerProvider)
            .isEnabled(
              FeatureFlags.newFeature,
            ),
        isTrue,
      );
    });

    testWidgets('clearing the override reaches it too', (tester) async {
      await container
          .read(featureFlagsManagerProvider)
          .setLocalOverride(FeatureFlags.newFeature, value: true);
      final seen = <bool>[];
      final sub = container.listen(
        isFeatureEnabledProvider(FeatureFlags.newFeature),
        (_, next) {
          if (next case AsyncData(:final value)) seen.add(value);
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(seen, [true]);

      await openCategory(tester, FeatureFlags.newFeature);
      await tester.longPress(find.text(FeatureFlags.newFeature.value));
      await tester.pumpAndSettle();

      expect(seen.last, isFalse);
    });
  });
}
