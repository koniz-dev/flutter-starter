import 'dart:async';

import 'package:flutter_starter/features/auth/demo/demo_auth.dart';

/// Runs before every test file under test/.
///
/// The test environment is a development build with no BASE_URL, which is
/// exactly when the app switches to the offline demo sign-in. Tests exercise
/// the real auth path by default; the demo tests opt back in
/// (koniz-dev/flutter-starter#628).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  DemoAuth.debugEnabledOverride = false;
  await testMain();
}
