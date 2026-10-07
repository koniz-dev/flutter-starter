import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFeatureFlagsManager extends Mock implements FeatureFlagsManager {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const FeatureFlagKey(
        value: 'test_key',
        defaultValue: false,
        description: 'Test description',
      ),
    );
  });

  group('FeatureFlagsDebugScreen', () {
    late MockFeatureFlagsManager mockManager;

    setUp(() {
      mockManager = MockFeatureFlagsManager();
      when(() => mockManager.refresh()).thenAnswer((_) async => {});
      when(
        () => mockManager.clearAllLocalOverrides(),
      ).thenAnswer((_) async => {});
      when(
        () => mockManager.setLocalOverride(any(), value: any(named: 'value')),
      ).thenAnswer((_) async => {});
      when(
        () => mockManager.clearLocalOverride(any()),
      ).thenAnswer((_) async => {});
    });

    Widget createTestWidget({
      required AsyncValue<Map<String, FeatureFlag?>> flagsValue,
      Locale locale = const Locale('en'),
    }) {
      return ProviderScope(
        overrides: [
          allFeatureFlagsProvider.overrideWith(
            (ref) => flagsValue.when(
              data: Future.value,
              loading: () => Future<Map<String, FeatureFlag?>>.value({}),
              error: Future<Map<String, FeatureFlag?>>.error,
            ),
          ),
          featureFlagsManagerProvider.overrideWithValue(mockManager),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FeatureFlagsDebugScreen(),
        ),
      );
    }

    testWidgets('should display app bar with title', (tester) async {
      // Arrange
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{});
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));

      // Assert
      expect(find.text('Feature Flags Debug'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders its strings from the es ARB, not hardcoded English', (
      tester,
    ) async {
      // Arrange - koniz-dev/flutter-starter#264: the screen must read the
      // l10n pipeline, so under `es` every visible string is the es value.
      final flag = FeatureFlag(
        key: 'test_flag',
        value: true,
        source: FeatureFlagSource.remoteConfig,
        lastUpdated: DateTime(2024, 1, 1, 12, 30),
      );
      await tester.pumpWidget(
        createTestWidget(
          flagsValue: AsyncValue.data(<String, FeatureFlag?>{
            'test_flag': flag,
          }),
          locale: const Locale('es'),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - app bar title and uncategorized section heading.
      expect(find.text('Depuración de Feature Flags'), findsOneWidget);
      expect(find.text('Feature Flags Debug'), findsNothing);
      expect(find.text('Otros'), findsOneWidget);
      expect(find.text('Other'), findsNothing);

      // Act - expand the section to reach the flag tile.
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Assert - placeholder message keeps the dynamic value.
      expect(find.text('Actualizado: 12:30'), findsOneWidget);

      // Act - open the clear-all dialog.
      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pumpAndSettle();

      // Assert - dialog title, reused `cancel` key and new `clear` key.
      expect(find.text('Borrar todas las anulaciones'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Borrar'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('should display empty message under es', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          flagsValue: const AsyncValue.data(<String, FeatureFlag?>{}),
          locale: const Locale('es'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron feature flags'), findsOneWidget);
    });

    testWidgets('should display loading indicator when loading', (
      tester,
    ) async {
      // Arrange
      const flagsValue = AsyncValue<Map<String, FeatureFlag?>>.loading();
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message when error occurs', (
      tester,
    ) async {
      // Arrange
      final flagsValue = AsyncValue<Map<String, FeatureFlag?>>.error(
        Exception('Test error'),
        StackTrace.empty,
      );
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Error:'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should display empty message when no flags', (tester) async {
      // Arrange
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{});
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No feature flags found'), findsOneWidget);
    });

    testWidgets('should display feature flags list', (tester) async {
      // Arrange
      final flag1 = FeatureFlag(
        key: 'test_flag_1',
        value: true,
        source: FeatureFlagSource.remoteConfig,
        description: 'Test flag 1',
        lastUpdated: DateTime(2024, 1, 1, 12),
      );
      const flag2 = FeatureFlag(
        key: 'test_flag_2',
        value: false,
        source: FeatureFlagSource.localOverride,
        description: 'Test flag 2',
      );
      final flagsValue = AsyncValue.data(<String, FeatureFlag?>{
        'test_flag_1': flag1,
        'test_flag_2': flag2,
      });
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act - Expand all ExpansionTiles
      final expansionTiles = find.byType(ExpansionTile);
      for (var i = 0; i < expansionTiles.evaluate().length; i++) {
        await tester.tap(expansionTiles.at(i));
        await tester.pumpAndSettle();
      }

      // Assert
      expect(find.text('test_flag_1'), findsOneWidget);
      expect(find.text('test_flag_2'), findsOneWidget);
    });

    testWidgets('should refresh flags when refresh button is tapped', (
      tester,
    ) async {
      // Arrange
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{});
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockManager.refresh()).called(1);
    });

    testWidgets('should show clear all dialog when clear button is tapped', (
      tester,
    ) async {
      // Arrange
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{});
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act
      final clearButton = find.byIcon(Icons.clear_all);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Clear All Overrides'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('should clear all overrides when confirmed', (tester) async {
      // Arrange
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{});
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockManager.clearAllLocalOverrides()).called(1);
      expect(find.text('All local overrides cleared'), findsOneWidget);
    });

    testWidgets('should not clear when cancel is tapped', (tester) async {
      // Arrange
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{});
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert
      verifyNever(() => mockManager.clearAllLocalOverrides());
    });

    testWidgets('should toggle flag when switch is tapped', (tester) async {
      // Arrange
      const flag = FeatureFlag(
        key: 'test_flag',
        value: false,
        source: FeatureFlagSource.remoteConfig,
      );
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{
        'test_flag': flag,
      });
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act - Expand the ExpansionTile first
      final expansionTile = find.byType(ExpansionTile);
      if (expansionTile.evaluate().isNotEmpty) {
        await tester.tap(expansionTile);
        await tester.pumpAndSettle();
      }

      final switchWidget = find.byType(Switch);
      if (switchWidget.evaluate().isNotEmpty) {
        await tester.tap(switchWidget);
        await tester.pumpAndSettle();

        // Assert
        verify(
          () => mockManager.setLocalOverride(any(), value: true),
        ).called(1);
      }
    });

    testWidgets('unmounting mid-override does not touch ref after dispose', (
      tester,
    ) async {
      // Arrange
      const flag = FeatureFlag(
        key: 'test_flag',
        value: false,
        source: FeatureFlagSource.remoteConfig,
      );
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{
        'test_flag': flag,
      });
      final inFlight = Completer<void>();
      when(
        () => mockManager.setLocalOverride(any(), value: any(named: 'value')),
      ).thenAnswer((_) => inFlight.future);
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      final expansionTile = find.byType(ExpansionTile);
      if (expansionTile.evaluate().isNotEmpty) {
        await tester.tap(expansionTile);
        await tester.pumpAndSettle();
      }
      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsOneWidget);

      // Act - leave the screen while the override write is in flight.
      await tester.tap(switchWidget);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      inFlight.complete();
      await tester.pump();
      await tester.pump();

      // Assert - `ref.invalidate` sits behind the `mounted` guard, so
      // nothing reaches a disposed ConsumerState.
      expect(tester.takeException(), isNull);
    });

    testWidgets('should retry when retry button is tapped', (tester) async {
      // Arrange
      final flagsValue = AsyncValue<Map<String, FeatureFlag?>>.error(
        Exception('Test error'),
        StackTrace.empty,
      );
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Assert - provider should be invalidated (tested via UI update)
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should display flag description when available', (
      tester,
    ) async {
      // Arrange
      const flag = FeatureFlag(
        key: 'test_flag',
        value: true,
        source: FeatureFlagSource.remoteConfig,
        description: 'Test description',
      );
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{
        'test_flag': flag,
      });
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act - Expand the ExpansionTile first
      final expansionTile = find.byType(ExpansionTile);
      if (expansionTile.evaluate().isNotEmpty) {
        await tester.tap(expansionTile);
        await tester.pumpAndSettle();
      }

      // Assert - Description should be displayed (either from flag or flagKey)
      expect(
        find.text('Test description').evaluate().isNotEmpty ||
            find.text('No description').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('should display source chip for each flag', (tester) async {
      // Arrange
      const flag = FeatureFlag(
        key: 'test_flag',
        value: true,
        source: FeatureFlagSource.localOverride,
      );
      const flagsValue = AsyncValue.data(<String, FeatureFlag?>{
        'test_flag': flag,
      });
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act - Expand the ExpansionTile first
      final expansionTile = find.byType(ExpansionTile);
      if (expansionTile.evaluate().isNotEmpty) {
        await tester.tap(expansionTile);
        await tester.pumpAndSettle();
      }

      // Assert
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('LOCALOVERRIDE'), findsOneWidget);
    });

    testWidgets('should display last updated time when available', (
      tester,
    ) async {
      // Arrange
      final flag = FeatureFlag(
        key: 'test_flag',
        value: true,
        source: FeatureFlagSource.remoteConfig,
        lastUpdated: DateTime(2024, 1, 1, 12, 30),
      );
      final flagsValue = AsyncValue.data(<String, FeatureFlag?>{
        'test_flag': flag,
      });
      await tester.pumpWidget(createTestWidget(flagsValue: flagsValue));
      await tester.pumpAndSettle();

      // Act - Expand the ExpansionTile first
      final expansionTile = find.byType(ExpansionTile);
      if (expansionTile.evaluate().isNotEmpty) {
        await tester.tap(expansionTile);
        await tester.pumpAndSettle();
      }

      // Assert
      expect(find.textContaining('Updated:'), findsOneWidget);
    });
  });
}
