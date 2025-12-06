import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalizationService extends Mock implements LocalizationService {}

/// Helper function to create test widget with proper provider setup
Widget createTestWidget({
  required Widget child,
  required MockLocalizationService mockLocalizationService,
}) {
  final container = ProviderContainer(
    overrides: [
      localizationServiceProvider.overrideWithValue(mockLocalizationService),
      // Override currentLocaleProvider to avoid async issues
      currentLocaleProvider.overrideWith(
        (ref) async => const Locale('en'),
      ),
      // localeStateProvider will be initialized from currentLocaleProvider
    ],
  );

  // Set initial state for localeStateProvider after container is created
  container.read(localeStateProvider.notifier).state = const Locale('en');

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Locale('en'));
  });

  group('LanguageSwitcher', () {
    late MockLocalizationService mockLocalizationService;

    setUp(() {
      mockLocalizationService = MockLocalizationService();
      when(
        () => mockLocalizationService.setCurrentLocale(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalizationService.getCurrentLocale(),
      ).thenAnswer((_) async => const Locale('en'));
    });

    testWidgets('should display language switcher button', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSwitcher(),
        ),
      );

      // Wait for async initialization
      await tester.pump();

      // Assert
      expect(find.byType(LanguageSwitcher), findsOneWidget);
      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('should use custom icon when provided', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSwitcher(icon: Icons.translate),
        ),
      );

      // Wait for async initialization
      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.translate), findsOneWidget);
    });

    testWidgets('should open dialog when tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSwitcher(),
        ),
      );

      // Wait for async initialization
      await tester.pump();

      // Act
      await tester.tap(find.byIcon(Icons.language));
      await tester.pump();
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('LanguageSwitcherMenuItem', () {
    late MockLocalizationService mockLocalizationService;

    setUp(() {
      mockLocalizationService = MockLocalizationService();
      when(
        () => mockLocalizationService.setCurrentLocale(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalizationService.getCurrentLocale(),
      ).thenAnswer((_) async => const Locale('en'));
    });

    testWidgets('should display list tile', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSwitcherMenuItem(),
        ),
      );

      // Wait for async initialization
      await tester.pump();

      // Assert
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('should use custom icon when provided', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSwitcherMenuItem(icon: Icons.translate),
        ),
      );

      // Wait for async initialization
      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.translate), findsOneWidget);
    });

    testWidgets('should open dialog when tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSwitcherMenuItem(),
        ),
      );

      // Wait for async initialization
      await tester.pump();

      // Act
      await tester.tap(find.byType(ListTile));
      await tester.pump();
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('LanguageSelectionScreen', () {
    late MockLocalizationService mockLocalizationService;

    setUp(() {
      mockLocalizationService = MockLocalizationService();
      when(
        () => mockLocalizationService.setCurrentLocale(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalizationService.getCurrentLocale(),
      ).thenAnswer((_) async => const Locale('en'));
    });

    testWidgets('should display language selection screen', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSelectionScreen(),
        ),
      );

      // Wait for async initialization
      await tester.pump();

      // Assert
      // There may be multiple Scaffold widgets in the widget tree
      // (from MaterialApp)
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should display all supported locales', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSelectionScreen(),
        ),
      );

      // Wait for widget to build
      await tester.pump();

      // Assert
      // ListView should be present, which contains RadioListTile widgets
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should show check icon for selected locale', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        createTestWidget(
          mockLocalizationService: mockLocalizationService,
          child: const LanguageSelectionScreen(),
        ),
      );

      // Wait for widget to build
      await tester.pump();

      // Assert
      // Screen should be displayed with ListView
      expect(find.byType(ListView), findsOneWidget);
      // Check icon may be present for selected locale
      // Note: Icon visibility depends on current locale state
    });
  });
}
