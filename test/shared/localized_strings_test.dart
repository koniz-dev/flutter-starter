// Regression tests for koniz-dev/flutter-starter#65, criteria 5, 6 and 11.
//
// Every user-visible and screen-reader string in `lib/shared/` and
// `lib/core/accessibility/` must come from the ARBs. These tests pump the
// affected widgets under `vi` and assert that none of the English literals the
// issue listed appear anywhere in the rendered text OR in the semantics tree.
//
// Note on evidence: a golden CANNOT prove any of this. `flutter test` renders
// text with the Ahem font, so every glyph is an opaque block. Which string is
// announced is only observable through the semantics tree, which is what these
// assertions read.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_widgets.dart';
import 'package:flutter_starter/shared/widgets/error_widget.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';
import 'package:flutter_starter/shared/widgets/optimized_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every English literal the issue reported as hardcoded, from sections 5 and
/// 6 of koniz-dev/flutter-starter#65.
const _englishLiterals = <String>[
  'No items found',
  'Load More',
  'Retry',
  'Progress indicator',
  'Loading',
  'Disabled',
  'Opens language selection dialog',
  'Attempts to reload the content',
  'Error icon',
  'Error: ',
  'Focused on ',
  'Navigated to ',
  'percent',
  'English (United States)',
];

Widget _viApp(Widget child) {
  final container = ProviderContainer(
    overrides: [
      currentLocaleProvider.overrideWith((ref) async => const Locale('vi')),
    ],
  );
  container.read(localeStateProvider.notifier).locale = const Locale('vi');

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('vi'),
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

/// All strings the semantics tree exposes: labels, hints, values and tooltips.
List<String> _semanticsStrings(WidgetTester tester) {
  final strings = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    for (final value in [
      data.label,
      data.hint,
      data.value,
      data.tooltip,
      data.increasedValue,
      data.decreasedValue,
    ]) {
      if (value.isNotEmpty) {
        strings.add(value);
      }
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // `getSemantics` walks up to the nearest node, which for the app root is
  // the root of the semantics tree.
  visit(tester.getSemantics(find.byType(MaterialApp)));
  return strings;
}

/// All rendered `Text` strings.
List<String> _renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .where((data) => data.isNotEmpty)
    .toList();

void _expectNoEnglishLiterals(WidgetTester tester) {
  final observed = [..._renderedText(tester), ..._semanticsStrings(tester)];
  for (final literal in _englishLiterals) {
    for (final seen in observed) {
      expect(
        seen.contains(literal),
        isFalse,
        reason: 'hardcoded English "$literal" leaked into "$seen" under vi',
      );
    }
  }
}

void main() {
  final vi = lookupAppLocalizations(const Locale('vi'));

  group('lib/shared strings under vi', () {
    testWidgets('OptimizedListView empty state is localized', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _viApp(
          OptimizedListView<String>(
            items: const [],
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(vi.noItemsFound), findsOneWidget);
      _expectNoEnglishLiterals(tester);
      handle.dispose();
    });

    testWidgets('OptimizedListView error, retry and load-more are localized', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _viApp(
          OptimizedListView<String>(
            items: const ['Item 0'],
            hasMore: true,
            enablePrefetch: false,
            onLoadMore: () async => (<String>[], false),
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(vi.loadMore), findsOneWidget);
      _expectNoEnglishLiterals(tester);

      await tester.pumpWidget(
        _viApp(
          OptimizedListView<String>(
            items: const [],
            error: 'loi mang',
            onRetry: () {},
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(vi.retry), findsOneWidget);
      _expectNoEnglishLiterals(tester);
      handle.dispose();
    });

    testWidgets('AppErrorWidget label, hint and retry are localized', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _viApp(AppErrorWidget(message: 'loi mang', onRetry: () {})),
      );
      await tester.pumpAndSettle();

      final semantics = _semanticsStrings(tester);
      expect(find.text(vi.retry), findsOneWidget);
      expect(semantics, contains(vi.retryHint));
      expect(semantics, contains('${vi.error}: loi mang'));
      _expectNoEnglishLiterals(tester);
      handle.dispose();
    });

    testWidgets('AppErrorWidget announces its message exactly once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _viApp(AppErrorWidget(message: 'loi mang', onRetry: () {})),
      );
      await tester.pumpAndSettle();

      final mentions = _semanticsStrings(
        tester,
      ).where((s) => s.contains('loi mang')).toList();
      expect(
        mentions.length,
        1,
        reason:
            'duplicated Semantics wrappers made TalkBack read the error '
            'twice; got $mentions',
      );
      handle.dispose();
    });

    testWidgets('AccessibleButton state words are localized', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _viApp(
          const AccessibleButton(
            label: 'Gui',
            onPressed: null,
            isEnabled: false,
            isLoading: true,
          ),
        ),
      );
      // Not pumpAndSettle: the loading spinner animates forever.
      await tester.pump();

      expect(
        _semanticsStrings(tester),
        contains('${vi.stateLoading}, Gui, ${vi.stateDisabled}'),
      );
      _expectNoEnglishLiterals(tester);
      handle.dispose();
    });

    testWidgets('AccessibleProgressIndicator label and value are localized', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _viApp(const AccessibleProgressIndicator(value: 0.5)),
      );
      await tester.pump();

      final semantics = _semanticsStrings(tester);
      expect(semantics, contains(vi.progressIndicator));
      expect(semantics, contains(vi.percentValue(50)));
      _expectNoEnglishLiterals(tester);
      handle.dispose();
    });

    testWidgets('LanguageSwitcher hint is localized', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_viApp(const LanguageSwitcher()));
      await tester.pumpAndSettle();

      expect(_semanticsStrings(tester), contains(vi.selectLanguageHint));
      _expectNoEnglishLiterals(tester);
      handle.dispose();
    });

    testWidgets('LanguageSelectionScreen shows endonyms, not English', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_viApp(const LanguageSelectionScreen()));
      await tester.pumpAndSettle();

      // Endonyms are deliberately in their own language, so the English entry
      // reads "English", not a translated name - but it must come from
      // SupportedLocale, not from a switch statement in the widget.
      for (final supported in SupportedLocale.values) {
        expect(find.text(supported.displayName), findsOneWidget);
        expect(find.text(supported.regionDisplayName), findsOneWidget);
      }
      expect(find.text(vi.selectLanguage), findsWidgets);
      handle.dispose();
    });
  });
}
