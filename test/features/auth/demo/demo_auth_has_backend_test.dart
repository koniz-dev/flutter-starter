// Demo auth keys on AppConfig.hasBackend rather than a rule of its own. This
// lives with the demo so that deleting the demo deletes it too.

import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/features/auth/demo/demo_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo auth is on exactly when a debug build has no backend', () {
    for (final environment in ['development', 'staging', 'production']) {
      for (final baseUrl in ['', 'http://localhost:3000']) {
        for (final debugBuild in [true, false]) {
          expect(
            DemoAuth.isEnabledFor(
              debugBuild: debugBuild,
              environment: environment,
              baseUrl: baseUrl,
            ),
            debugBuild &&
                !AppConfig.hasBackendFor(
                  environment: environment,
                  baseUrl: baseUrl,
                ),
            reason: '$environment, BASE_URL="$baseUrl", debug=$debugBuild',
          );
        }
      }
    }
  });
}
