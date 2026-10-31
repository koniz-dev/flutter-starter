// The manager's override methods dropped the repository's Result, so the
// debug screen showed its success snackbar for a failed write; and
// allFeatureFlagsProvider turned a repository failure into an empty map, so
// the screen said "no flags" instead of showing the error and its retry.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockManager extends Mock implements FeatureFlagsManager {}

class _MockRepository extends Mock implements FeatureFlagsRepository {}

const _failure = ResultFailure<void>(CacheFailure('write failed'));

const _flag = FeatureFlag(
  key: 'test_flag',
  value: false,
  source: FeatureFlagSource.localOverride,
);

Widget _app(List<Object> overrides) => ProviderScope(
  retry: (_, _) => null,
  overrides: overrides.cast(),
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

void main() {
  setUpAll(() {
    registerFallbackValue(
      const FeatureFlagKey(value: 'k', defaultValue: false, description: 'd'),
    );
  });

  late _MockManager manager;

  setUp(() {
    manager = _MockManager();
    when(() => manager.refresh()).thenAnswer((_) async {});
    when(
      () => manager.setLocalOverride(any(), value: any(named: 'value')),
    ).thenAnswer((_) async => _failure);
    when(() => manager.clearLocalOverride(any())).thenAnswer(
      (_) async => _failure,
    );
    when(() => manager.clearAllLocalOverrides()).thenAnswer(
      (_) async => _failure,
    );
  });

  Future<void> pumpWithFlag(WidgetTester tester) async {
    await tester.pumpWidget(
      _app([
        allFeatureFlagsProvider.overrideWith(
          (ref) async => <String, FeatureFlag?>{'test_flag': _flag},
        ),
        featureFlagsManagerProvider.overrideWithValue(manager),
      ]),
    );
    await tester.pumpAndSettle();
    final tile = find.byType(ExpansionTile);
    if (tile.evaluate().isNotEmpty) {
      await tester.tap(tile.first);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a failed override write shows the error, not success', (
    tester,
  ) async {
    await pumpWithFlag(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('Error: write failed'), findsOneWidget);
    expect(find.text('test_flag enabled'), findsNothing);
  });

  testWidgets('a failed clear of one override shows the error', (
    tester,
  ) async {
    await pumpWithFlag(tester);

    await tester.longPress(find.text('test_flag').last);
    await tester.pump();

    expect(find.text('Error: write failed'), findsOneWidget);
    expect(find.text('Override cleared for test_flag'), findsNothing);
  });

  testWidgets('a failed clear of all overrides shows the error', (
    tester,
  ) async {
    await pumpWithFlag(tester);

    await tester.tap(find.byIcon(Icons.clear_all));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(find.text('Error: write failed'), findsOneWidget);
    expect(find.text('All local overrides cleared'), findsNothing);
  });

  testWidgets('a repository that cannot list the flags shows the error and '
      'its retry, not an empty list', (tester) async {
    final repository = _MockRepository();
    when(repository.getAllFlags).thenAnswer(
      (_) async => const ResultFailure(CacheFailure('flag store unavailable')),
    );
    await tester.pumpWidget(
      _app([featureFlagsRepositoryProvider.overrideWithValue(repository)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error: flag store unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No feature flags found'), findsNothing);
  });
}
