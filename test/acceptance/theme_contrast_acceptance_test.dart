@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'acceptance_helpers.dart';

/// A sample of the text styles the theme installs, on the scaffold background
/// they are actually painted on.
///
/// The point of the golden is colour: before this fix `labelLarge` was
/// `#FFFFFF` in the light `TextTheme`, so the label row rendered as nothing at
/// all on the `#F8F9FA` scaffold. Ahem draws every glyph as a solid block, so
/// the PNG shows exactly which rows have visible ink and at what colour - it
/// cannot show what any of them say.
class _TextStyleSample extends StatelessWidget {
  const _TextStyleSample();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bar')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Display', style: text.displayLarge),
            const SizedBox(height: 12),
            Text('Body', style: text.bodyLarge),
            const SizedBox(height: 12),
            Text('Muted', style: text.bodyMedium),
            const SizedBox(height: 12),
            Text('Label', style: text.labelLarge),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () {}, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('theme contrast acceptance', () {
    testWidgets('light theme renders every text style with visible ink', (
      tester,
    ) async {
      await pumpAcceptance(tester, const _TextStyleSample());

      // A golden cannot prove wording; finders can.
      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Muted'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await captureAcceptanceGolden(
        find.byType(_TextStyleSample),
        'theme_text_styles_light',
      );
    });

    testWidgets('dark theme renders every text style with visible ink', (
      tester,
    ) async {
      await pumpAcceptance(
        tester,
        const _TextStyleSample(),
        theme: AppTheme.darkTheme,
      );

      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Muted'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await captureAcceptanceGolden(
        find.byType(_TextStyleSample),
        'theme_text_styles_dark',
      );
    });
  });
}
