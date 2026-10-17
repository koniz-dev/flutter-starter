import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

// koniz-dev/flutter-starter#349: LoginScreen and RegisterScreen were a
// non-scrolling Padding > Form > Column(center). When the soft keyboard took
// 300px of a 360x640 phone, or the phone was turned to 640x360, the column
// overflowed (the yellow-and-black stripe) and the submit button was pushed
// off-screen where it could not be reached.

const _phone = Size(360, 640);
const _landscape = Size(640, 360);

final _screens = <String, Key>{
  AppRoutes.login: UiKeys.loginSubmit,
  AppRoutes.register: UiKeys.registerSubmit,
};

Future<void> _open(WidgetTester tester, String route, Size size) async {
  final router = await pumpAppRouter(
    tester,
    surfaceSize: size,
    overrides: [sessionRestorationProvider.overrideWith((ref) async {})],
  );
  router.go(route);
  await tester.pumpAndSettle();
}

/// Taps [submit] with every field empty, so every validator shows its error.
Future<void> _submitEmpty(WidgetTester tester, Key submit) async {
  await tester.ensureVisible(find.byKey(submit));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(submit));
  await tester.pumpAndSettle();
}

void _expectReachable(WidgetTester tester, Key submit) {
  final finder = find.byKey(submit);
  final rect = tester.getRect(finder);
  final screen = Offset.zero & tester.view.physicalSize;
  expect(screen.contains(rect.center), isTrue, reason: 'submit at $rect');

  final hit = tester.hitTestOnBinding(rect.center);
  final button = tester.renderObject(finder);
  expect(
    hit.path.any((entry) => entry.target == button),
    isTrue,
    reason: 'a tap on the submit button reaches it',
  );
}

void main() {
  for (final MapEntry(key: route, value: submit) in _screens.entries) {
    group(route, () {
      testWidgets('criterion 1: no overflow at 360x640 with a 300px keyboard, '
          'before and after a failed submit', (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);

        await _open(tester, route, _phone);
        expect(tester.takeException(), isNull);

        await _submitEmpty(tester, submit);
        expect(find.byType(TextFormField), findsWidgets);
        expect(tester.takeException(), isNull);
        _expectReachable(tester, submit);
      });

      testWidgets('criterion 2: no overflow at 640x360, and submit can be '
          'scrolled to and hit-tested', (tester) async {
        await _open(tester, route, _landscape);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.byKey(submit));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _expectReachable(tester, submit);

        await _submitEmpty(tester, submit);
        expect(tester.takeException(), isNull);
        _expectReachable(tester, submit);
      });
    });
  }
}
