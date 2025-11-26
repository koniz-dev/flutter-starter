import 'package:flutter/material.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_screen_mixin.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceService extends Mock implements PerformanceService {}

class MockPerformanceTrace extends Mock implements PerformanceTrace {}

void main() {
  group('PerformanceScreenMixin', () {
    late MockPerformanceService mockPerformanceService;
    late MockPerformanceTrace mockTrace;

    setUp(() {
      mockPerformanceService = MockPerformanceService();
      mockTrace = MockPerformanceTrace();

      when(() => mockPerformanceService.isEnabled).thenReturn(true);
      when(() => mockPerformanceService.startScreenTrace(any()))
          .thenReturn(mockTrace);
      when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
      when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
      when(() => mockTrace.startSync()).thenReturn(null);
      when(() => mockTrace.stopSync()).thenReturn(null);
    });

    testWidgets('should start screen trace on init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _TestScreenWithMixin(
            performanceService: mockPerformanceService,
          ),
        ),
      );

      verify(
        () => mockPerformanceService.startScreenTrace('_TestScreenWithMixin'),
      ).called(1);
      verify(
        () => mockTrace.putAttribute(
          PerformanceAttributes.screenName,
          '_TestScreenWithMixin',
        ),
      ).called(1);
      verify(() => mockTrace.startSync()).called(1);
    });

    testWidgets('should stop screen trace on dispose', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _TestScreenWithMixin(
            performanceService: mockPerformanceService,
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      verify(
        () => mockTrace.putMetric(PerformanceMetrics.success, 1),
      ).called(1);
      verify(() => mockTrace.stopSync()).called(1);
    });

    testWidgets('should mark screen as loaded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _TestScreenWithMixin(
            performanceService: mockPerformanceService,
          ),
        ),
      );

      tester
          .state<_TestScreenWithMixinState>(
            find.byType(_TestScreenWithMixin),
          )
          .markScreenLoaded();

      verify(() => mockTrace.putMetric(PerformanceMetrics.screenLoadTime, 1))
          .called(1);
    });

    testWidgets('should record custom metric', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _TestScreenWithMixin(
            performanceService: mockPerformanceService,
          ),
        ),
      );

      tester
          .state<_TestScreenWithMixinState>(
            find.byType(_TestScreenWithMixin),
          )
          .recordScreenMetric('custom_metric', 42);

      verify(() => mockTrace.putMetric('custom_metric', 42)).called(1);
    });

    testWidgets('should record custom attribute', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _TestScreenWithMixin(
            performanceService: mockPerformanceService,
          ),
        ),
      );

      tester
          .state<_TestScreenWithMixinState>(
            find.byType(_TestScreenWithMixin),
          )
          .recordScreenAttribute('custom_attr', 'value');

      verify(() => mockTrace.putAttribute('custom_attr', 'value')).called(1);
    });

    testWidgets('should not start trace when service is disabled',
        (tester) async {
      when(() => mockPerformanceService.isEnabled).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: _TestScreenWithMixin(
            performanceService: mockPerformanceService,
          ),
        ),
      );

      verifyNever(() => mockPerformanceService.startScreenTrace(any()));
    });

    testWidgets('should use custom screen name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _TestScreenWithCustomName(
            performanceService: mockPerformanceService,
          ),
        ),
      );

      verify(() => mockPerformanceService.startScreenTrace('custom_screen'))
          .called(1);
    });
  });

  group('PerformanceScreenWrapper', () {
    late MockPerformanceService mockPerformanceService;
    late MockPerformanceTrace mockTrace;

    setUp(() {
      mockPerformanceService = MockPerformanceService();
      mockTrace = MockPerformanceTrace();

      when(() => mockPerformanceService.isEnabled).thenReturn(true);
      when(() => mockPerformanceService.startScreenTrace(any()))
          .thenReturn(mockTrace);
      when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
      when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
      when(() => mockTrace.startSync()).thenReturn(null);
      when(() => mockTrace.stopSync()).thenReturn(null);
    });

    testWidgets('should wrap child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreenWrapper(
            screenName: 'test_screen',
            performanceService: mockPerformanceService,
            child: const Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      verify(() => mockPerformanceService.startScreenTrace('test_screen'))
          .called(1);
    });

    testWidgets('should stop trace on dispose', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreenWrapper(
            screenName: 'test_screen',
            performanceService: mockPerformanceService,
            child: const Text('Test'),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      verify(
        () => mockTrace.putMetric(PerformanceMetrics.success, 1),
      ).called(1);
      verify(() => mockTrace.stopSync()).called(1);
    });

    testWidgets('should not start trace when service is disabled',
        (tester) async {
      when(() => mockPerformanceService.isEnabled).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceScreenWrapper(
            screenName: 'test_screen',
            performanceService: mockPerformanceService,
            child: const Text('Test'),
          ),
        ),
      );

      verifyNever(() => mockPerformanceService.startScreenTrace(any()));
    });
  });
}

class _TestScreenWithMixin extends StatefulWidget {
  const _TestScreenWithMixin({required this.performanceService});

  final PerformanceService? performanceService;

  @override
  State<_TestScreenWithMixin> createState() => _TestScreenWithMixinState();
}

class _TestScreenWithMixinState extends State<_TestScreenWithMixin>
    with PerformanceScreenMixin {
  @override
  PerformanceService? get performanceService => widget.performanceService;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Text('Test Screen'),
    );
  }
}

class _TestScreenWithCustomName extends StatefulWidget {
  const _TestScreenWithCustomName({required this.performanceService});

  final PerformanceService? performanceService;

  @override
  State<_TestScreenWithCustomName> createState() =>
      _TestScreenWithCustomNameState();
}

class _TestScreenWithCustomNameState extends State<_TestScreenWithCustomName>
    with PerformanceScreenMixin {
  @override
  String get screenName => 'custom_screen';

  @override
  PerformanceService? get performanceService => widget.performanceService;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Text('Custom Screen'),
    );
  }
}
