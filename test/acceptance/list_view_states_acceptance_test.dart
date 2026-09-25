@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/optimized_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'acceptance_helpers.dart';

/// Visual evidence for koniz-dev/flutter-starter#65, criterion 2.
///
/// The two PNGs exist to be compared with each other: an empty list that
/// **failed** must not look like an empty list that **succeeded with no
/// results**. `list_view_empty_state` is a single short centred line;
/// `list_view_error_state` is an error-coloured icon, a message block and a
/// filled retry button.
///
/// What these goldens cannot show: the wording. Ahem draws every glyph as an
/// opaque block, so "No items found" and "BOOM network failed" are
/// indistinguishable as pixels. The wording is asserted with `find.text` in
/// the same tests and in `test/shared/localized_strings_test.dart`.
class _ListHost extends StatelessWidget {
  const _ListHost({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: 400,
        child: OptimizedListView<String>(
          items: const [],
          error: error,
          onRetry: error == null ? null : () {},
          itemBuilder: (context, item, index) => Text(item),
        ),
      ),
    );
  }
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('OptimizedListView state acceptance', () {
    testWidgets('an empty list that loaded fine shows the empty state', (
      tester,
    ) async {
      await pumpAcceptance(tester, const _ListHost(error: null));

      expect(find.text(en.noItemsFound), findsOneWidget);
      expect(find.text(en.retry), findsNothing);

      await captureAcceptanceGolden(
        find.byType(_ListHost),
        'list_view_empty_state',
      );
    });

    testWidgets('an empty list that failed shows the error and a retry', (
      tester,
    ) async {
      await pumpAcceptance(
        tester,
        const _ListHost(error: 'BOOM network failed'),
      );

      expect(find.text('BOOM network failed'), findsOneWidget);
      expect(find.text(en.retry), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text(en.noItemsFound), findsNothing);

      await captureAcceptanceGolden(
        find.byType(_ListHost),
        'list_view_error_state',
      );
    });
  });
}
