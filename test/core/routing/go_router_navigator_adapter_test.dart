import 'package:flutter_starter/core/routing/adapters/go_router_navigator_adapter.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('GoRouterNavigatorAdapter', () {
    late _MockGoRouter router;
    late GoRouterNavigatorAdapter navigator;

    setUp(() {
      router = _MockGoRouter();
      navigator = GoRouterNavigatorAdapter(router);
    });

    test('toHome should go to home route', () async {
      when(() => router.go(any())).thenAnswer((_) {});
      await navigator.toHome();
      verify(() => router.go(AppRoutes.home)).called(1);
    });

    test('toLogin should go to login route', () async {
      when(() => router.go(any())).thenAnswer((_) {});
      await navigator.toLogin();
      verify(() => router.go(AppRoutes.login)).called(1);
    });

    test('toRegister should go to register route', () async {
      when(() => router.go(any())).thenAnswer((_) {});
      await navigator.toRegister();
      verify(() => router.go(AppRoutes.register)).called(1);
    });

    test('toTasks should go to tasks route', () async {
      when(() => router.go(any())).thenAnswer((_) {});
      await navigator.toTasks();
      verify(() => router.go('/tasks')).called(1);
    });

    test('toTaskDetail should go to task detail route', () async {
      when(() => router.go(any())).thenAnswer((_) {});
      await navigator.toTaskDetail('abc');
      verify(() => router.go('/tasks/abc')).called(1);
    });

    test('push should push location with extra', () async {
      when(() => router.push(any(), extra: any(named: 'extra'))).thenAnswer(
        (_) async => null,
      );
      await navigator.push('/x', extra: const {'k': 1});
      verify(() => router.push('/x', extra: const {'k': 1})).called(1);
    });

    test('replace should pushReplacement location with extra', () async {
      when(
        () => router.pushReplacement(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
      await navigator.replace('/x', extra: 123);
      verify(() => router.pushReplacement('/x', extra: 123)).called(1);
    });

    test('back should pop when canPop is true', () async {
      when(() => router.canPop()).thenReturn(true);
      when(() => router.pop<String>(any())).thenAnswer((_) {});

      await navigator.back<String>('ok');

      verify(() => router.canPop()).called(1);
      verify(() => router.pop<String>('ok')).called(1);
      verifyNever(() => router.go(any()));
    });

    test('back should go to login when canPop is false', () async {
      when(() => router.canPop()).thenReturn(false);
      when(() => router.go(any())).thenAnswer((_) {});

      await navigator.back<void>();

      verify(() => router.canPop()).called(1);
      verify(() => router.go(AppRoutes.login)).called(1);
      verifyNever(() => router.pop<void>(any()));
    });
  });
}
