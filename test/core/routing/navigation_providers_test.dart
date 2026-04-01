import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/contracts/navigation_contracts.dart';
import 'package:flutter_starter/core/routing/adapters/go_router_navigator_adapter.dart';
import 'package:flutter_starter/core/routing/app_router.dart';
import 'package:flutter_starter/core/routing/navigation_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('appNavigatorProvider', () {
    test(
      'should return GoRouterNavigatorAdapter wrapping goRouterProvider',
      () {
        final router = _MockGoRouter();
        final container = ProviderContainer(
          overrides: [
            goRouterProvider.overrideWithValue(router),
          ],
        );
        addTearDown(container.dispose);

        final navigator = container.read(appNavigatorProvider);

        expect(navigator, isA<GoRouterNavigatorAdapter>());
        expect(navigator, isA<AppNavigator>());
      },
    );
  });
}
