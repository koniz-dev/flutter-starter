import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('without the auth module, sign-out fails loudly instead of doing '
      'nothing', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(signOutProvider)(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('authModuleOverrides'),
        ),
      ),
    );
  });
}
