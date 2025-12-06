import 'package:flutter/material.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/routing/navigation_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  group('NavigationLoggingObserver', () {
    late MockLoggingService mockLoggingService;
    late NavigationLoggingObserver observer;

    setUp(() {
      mockLoggingService = MockLoggingService();
      observer = NavigationLoggingObserver(
        loggingService: mockLoggingService,
      );
      when(
        () => mockLoggingService.info(
          any(),
          context: any(named: 'context'),
        ),
      ).thenReturn(null);
    });

    group('didPush', () {
      test('should log route push event', () {
        // Arrange
        final route = _MockRoute(name: '/test');
        final previousRoute = _MockRoute(name: '/previous');

        // Act
        observer.didPush(route, previousRoute);

        // Assert
        verify(
          () => mockLoggingService.info(
            'Navigation: Route Pushed',
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should log route push with route name', () {
        // Arrange
        final route = _MockRoute(name: '/home');
        final previousRoute = _MockRoute(name: '/login');

        // Act
        observer.didPush(route, previousRoute);

        // Assert
        final captured = verify(
          () => mockLoggingService.info(
            any(),
            context: captureAny(named: 'context'),
          ),
        ).captured;
        final context = captured.first as Map<String, dynamic>;
        expect(context['routeName'], '/home');
        expect(context['previousRouteName'], '/login');
      });

      test('should handle null previous route', () {
        // Arrange
        final route = _MockRoute(name: '/test');

        // Act
        observer.didPush(route, null);

        // Assert
        final captured = verify(
          () => mockLoggingService.info(
            any(),
            context: captureAny(named: 'context'),
          ),
        ).captured;
        final context = captured.first as Map<String, dynamic>;
        expect(context['routeName'], '/test');
        expect(context.containsKey('previousRouteName'), isFalse);
      });
    });

    group('didPop', () {
      test('should log route pop event', () {
        // Arrange
        final route = _MockRoute(name: '/test');
        final previousRoute = _MockRoute(name: '/previous');

        // Act
        observer.didPop(route, previousRoute);

        // Assert
        verify(
          () => mockLoggingService.info(
            'Navigation: Route Popped',
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should log route pop with route information', () {
        // Arrange
        final route = _MockRoute(name: '/tasks');
        final previousRoute = _MockRoute(name: '/home');

        // Act
        observer.didPop(route, previousRoute);

        // Assert
        final captured = verify(
          () => mockLoggingService.info(
            any(),
            context: captureAny(named: 'context'),
          ),
        ).captured;
        final context = captured.first as Map<String, dynamic>;
        expect(context['routeName'], '/tasks');
        expect(context['previousRouteName'], '/home');
      });
    });

    group('didRemove', () {
      test('should log route remove event', () {
        // Arrange
        final route = _MockRoute(name: '/test');
        final previousRoute = _MockRoute(name: '/previous');

        // Act
        observer.didRemove(route, previousRoute);

        // Assert
        verify(
          () => mockLoggingService.info(
            'Navigation: Route Removed',
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should log route remove with route information', () {
        // Arrange
        final route = _MockRoute(name: '/removed');
        final previousRoute = _MockRoute(name: '/current');

        // Act
        observer.didRemove(route, previousRoute);

        // Assert
        final captured = verify(
          () => mockLoggingService.info(
            any(),
            context: captureAny(named: 'context'),
          ),
        ).captured;
        final context = captured.first as Map<String, dynamic>;
        expect(context['routeName'], '/removed');
        expect(context['previousRouteName'], '/current');
      });
    });

    group('didReplace', () {
      test('should log route replace event', () {
        // Arrange
        final newRoute = _MockRoute(name: '/new');
        final oldRoute = _MockRoute(name: '/old');

        // Act
        observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);

        // Assert
        verify(
          () => mockLoggingService.info(
            'Navigation: Route Replaced',
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should not log when newRoute is null', () {
        // Arrange
        final oldRoute = _MockRoute(name: '/old');

        // Act
        observer.didReplace(oldRoute: oldRoute);

        // Assert
        verifyNever(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        );
      });

      test('should log route replace with route information', () {
        // Arrange
        final newRoute = _MockRoute(name: '/new-route');
        final oldRoute = _MockRoute(name: '/old-route');

        // Act
        observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);

        // Assert
        final captured = verify(
          () => mockLoggingService.info(
            any(),
            context: captureAny(named: 'context'),
          ),
        ).captured;
        final context = captured.first as Map<String, dynamic>;
        expect(context['routeName'], '/new-route');
        expect(context['previousRouteName'], '/old-route');
      });
    });

    group('_getRoutePath', () {
      test('should return route name when available', () {
        // Arrange
        final route = _MockRoute(name: '/test-path');
        final previousRoute = _MockRoute(name: '/previous');

        // Act
        observer.didPush(route, previousRoute);

        // Assert
        final captured = verify(
          () => mockLoggingService.info(
            any(),
            context: captureAny(named: 'context'),
          ),
        ).captured;
        final context = captured.first as Map<String, dynamic>;
        expect(context['routePath'], '/test-path');
      });

      test('should handle route with null name', () {
        // Arrange
        final route = _MockRoute();
        final previousRoute = _MockRoute(name: '/previous');

        // Act
        observer.didPush(route, previousRoute);

        // Assert
        verify(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should handle route with arguments containing uri', () {
        // Arrange
        final route = _MockRoute(
          arguments: {'uri': '/custom-uri'},
        );
        final previousRoute = _MockRoute(name: '/previous');

        // Act
        observer.didPush(route, previousRoute);

        // Assert
        verify(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
      });
    });

    group('Edge Cases', () {
      test('should handle route with empty name', () {
        // Arrange
        final route = _MockRoute(name: '');
        final previousRoute = _MockRoute(name: '/previous');

        // Act
        observer.didPush(route, previousRoute);

        // Assert
        verify(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should handle multiple navigation events', () {
        // Arrange
        final route1 = _MockRoute(name: '/route1');
        final route2 = _MockRoute(name: '/route2');
        final route3 = _MockRoute(name: '/route3');

        // Act
        observer
          ..didPush(route1, null)
          ..didPop(route2, route1)
          ..didReplace(newRoute: route3, oldRoute: route2);

        // Assert
        verify(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        ).called(3);
      });
    });
  });
}

class _MockRoute extends Mock implements Route<dynamic> {
  _MockRoute({this.name, this.arguments});

  final String? name;
  final Map<String, dynamic>? arguments;

  @override
  RouteSettings get settings => _MockRouteSettings(
    name: name,
    arguments: arguments,
  );

  @override
  String toString() => 'Route<dynamic>';
}

class _MockRouteSettings extends Mock implements RouteSettings {
  _MockRouteSettings({this.name, this.arguments});

  @override
  final String? name;

  @override
  final Object? arguments;
}
