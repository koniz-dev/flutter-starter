import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/widgets/feature_flag_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFeatureFlagsManager extends Mock implements FeatureFlagsManager {}

void main() {
  setUpAll(() {
    // Register fallback value for FeatureFlagKey to use with mocktail's any()
    registerFallbackValue(
      const FeatureFlagKey(
        value: 'test_flag',
        defaultValue: false,
        description: 'Test flag',
      ),
    );
  });
  group('FeatureFlagBuilder', () {
    late MockFeatureFlagsManager mockManager;

    setUp(() {
      mockManager = MockFeatureFlagsManager();
    });

    testWidgets('should show enabled builder when flag is enabled', (
      tester,
    ) async {
      when(() => mockManager.isEnabled(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FeatureFlagBuilder(
                flag: FeatureFlags.newFeature,
                enabledBuilder: (context) => const Text('Enabled'),
                disabledBuilder: (context) => const Text('Disabled'),
              ),
            ),
          ),
        ),
      );

      // Wait for async provider
      await tester.pumpAndSettle();

      expect(find.text('Enabled'), findsOneWidget);
      expect(find.text('Disabled'), findsNothing);
    });

    testWidgets('should show disabled builder when flag is disabled', (
      tester,
    ) async {
      when(() => mockManager.isEnabled(any())).thenAnswer((_) async => false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FeatureFlagBuilder(
                flag: FeatureFlags.newFeature,
                enabledBuilder: (context) => const Text('Enabled'),
                disabledBuilder: (context) => const Text('Disabled'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Enabled'), findsNothing);
    });

    testWidgets('should show loading builder when loading', (tester) async {
      when(() => mockManager.isEnabled(any())).thenAnswer(
        (_) => Future<bool>.delayed(
          const Duration(seconds: 1),
          () => true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FeatureFlagBuilder(
                flag: FeatureFlags.newFeature,
                enabledBuilder: (context) => const Text('Enabled'),
                disabledBuilder: (context) => const Text('Disabled'),
                loadingBuilder: (context) => const Text('Loading'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);

      // Advance time to complete the future and avoid pending timer
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'should show default loading indicator when no loading builder',
      (tester) async {
        when(() => mockManager.isEnabled(any())).thenAnswer(
          (_) => Future<bool>.delayed(
            const Duration(seconds: 1),
            () => true,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              featureFlagsManagerProvider.overrideWithValue(mockManager),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: FeatureFlagBuilder(
                  flag: FeatureFlags.newFeature,
                  enabledBuilder: (context) => const Text('Enabled'),
                  disabledBuilder: (context) => const Text('Disabled'),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Advance time to complete the future and avoid pending timer
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('should show disabled builder on error', (tester) async {
      when(
        () => mockManager.isEnabled(any()),
      ).thenThrow(Exception('Test error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FeatureFlagBuilder(
                flag: FeatureFlags.newFeature,
                enabledBuilder: (context) => const Text('Enabled'),
                disabledBuilder: (context) => const Text('Disabled'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('should show nothing when disabled and no disabled builder', (
      tester,
    ) async {
      when(() => mockManager.isEnabled(any())).thenAnswer((_) async => false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FeatureFlagBuilder(
                flag: FeatureFlags.newFeature,
                enabledBuilder: (context) => const Text('Enabled'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Enabled'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('FeatureFlagWidget', () {
    late MockFeatureFlagsManager mockManager;

    setUp(() {
      mockManager = MockFeatureFlagsManager();
    });

    testWidgets('should show child when flag is enabled', (tester) async {
      when(() => mockManager.isEnabled(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureFlagWidget(
                flag: FeatureFlags.newFeature,
                child: Text('Feature Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Feature Content'), findsOneWidget);
    });

    testWidgets('should show fallback when flag is disabled', (tester) async {
      when(() => mockManager.isEnabled(any())).thenAnswer((_) async => false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureFlagWidget(
                flag: FeatureFlags.newFeature,
                fallback: Text('Fallback Content'),
                child: Text('Feature Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fallback Content'), findsOneWidget);
      expect(find.text('Feature Content'), findsNothing);
    });

    testWidgets('should show nothing when disabled and no fallback', (
      tester,
    ) async {
      when(() => mockManager.isEnabled(any())).thenAnswer((_) async => false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsManagerProvider.overrideWithValue(mockManager),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureFlagWidget(
                flag: FeatureFlags.newFeature,
                child: Text('Feature Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Feature Content'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
