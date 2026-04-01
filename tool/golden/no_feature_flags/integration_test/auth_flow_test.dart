// Import main app package
import 'package:flutter_starter/main.dart' as app;
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('auth flow: enters credentials and navigates to dashboard', (
    $,
  ) async {
    app.main();
    await $.pumpAndSettle();
  });
}
