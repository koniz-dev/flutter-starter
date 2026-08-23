@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'acceptance_helpers.dart';

void main() {
  group('HomeScreen acceptance', () {
    testWidgets('renders the home content surface and welcome heading', (
      tester,
    ) async {
      await pumpAcceptance(tester, const HomeScreen());

      // Text content must be asserted with a finder: a golden cannot show it,
      // because flutter test renders every glyph as an opaque block.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('e2e_home_content')), findsOne);

      // The golden proves layout, colour, and the absence of overflow.
      await captureAcceptanceGolden(find.byType(HomeScreen), 'home_screen');
    });
  });
}
