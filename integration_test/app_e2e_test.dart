import 'package:flutter/material.dart';
import 'package:flutter_starter/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('E2E: Auth -> home (stripped starter; stable ValueKeys)', (
    $,
  ) async {
    app.main();
    await $.pumpAndSettle();

    if ($(#e2e_login_submit).exists) {
      await $(TextField).at(0).enterText('test@example.com');
      await $(TextField).at(1).enterText('password123');
      await $(#e2e_login_submit).tap();
      await $.pumpAndSettle();
    }

    expect($(#e2e_home_content), findsOneWidget);
  });
}
