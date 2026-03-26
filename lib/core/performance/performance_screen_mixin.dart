import 'package:flutter/material.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';

/// Mixin for automatic screen performance monitoring
///
/// This mixin can be used with StatefulWidget to automatically track
/// screen load times and rendering performance.
///
/// Usage:
/// ```dart
/// class MyScreen extends StatefulWidget {
///   const MyScreen({super.key});
///
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends State<MyScreen> with PerformanceScreenMixin {
///   @override
///   String get screenName => 'my_screen';
///
///   @override
///   void initState() {
///     super.initState();
///     // Your initialization code
///   }
/// }
/// ```
mixin PerformanceScreenMixin<T extends StatefulWidget> on State<T> {
  IPerformanceTrace? _screenTrace;
  IPerformanceService? _performanceService;

  /// The name of the screen for performance tracking
  /// Override this to provide a custom screen name
  String get screenName {
    return widget.runtimeType.toString().replaceAll('State', '');
  }

  /// The route name of the screen (optional)
  /// Override this to provide a custom route name
  String? get screenRoute => null;

  /// Get the performance service instance
  /// Override this if you need to provide a custom service
  IPerformanceService? get performanceService => _performanceService;

  /// Set the performance service instance
  /// This is typically called from the widget's build method or initState
  set performanceService(IPerformanceService? service) {
    _performanceService = service;
  }

  @override
  void initState() {
    super.initState();
    _startScreenTrace();
  }

  @override
  void dispose() {
    _stopScreenTrace();
    super.dispose();
  }

  /// Start tracking screen performance
  void _startScreenTrace() {
    final service = performanceService;
    if (service == null || !service.isEnabled) {
      return;
    }

    _screenTrace = service.startScreenTrace(screenName);
    if (_screenTrace != null) {
      _screenTrace!.putAttribute(
        PerformanceAttributes.screenName,
        screenName,
      );
      if (screenRoute != null) {
        _screenTrace!.putAttribute(
          PerformanceAttributes.screenRoute,
          screenRoute!,
        );
      }
      _screenTrace!.startSync();
    }
  }

  /// Stop tracking screen performance
  void _stopScreenTrace() {
    if (_screenTrace != null) {
      _screenTrace!.putMetric(PerformanceMetrics.success, 1);
      _screenTrace!.stopSync();
      _screenTrace = null;
    }
  }

  /// Mark screen as loaded (call this when screen data is ready)
  void markScreenLoaded() {
    if (_screenTrace != null) {
      _screenTrace!.putMetric(PerformanceMetrics.screenLoadTime, 1);
    }
  }

  /// Record a custom metric for the screen
  void recordScreenMetric(String metricName, int value) {
    if (_screenTrace != null) {
      _screenTrace!.putMetric(metricName, value);
    }
  }

  /// Record a custom attribute for the screen
  void recordScreenAttribute(String name, String value) {
    if (_screenTrace != null) {
      _screenTrace!.putAttribute(name, value);
    }
  }
}

/// Widget wrapper for automatic screen performance monitoring
///
/// This widget automatically tracks screen load times without requiring
/// mixins or manual trace management.
///
/// Usage:
/// ```dart
/// PerformanceScreenWrapper(
///   screenName: 'home',
///   performanceService: performanceService,
///   child: HomeScreen(),
/// )
/// ```
class PerformanceScreenWrapper extends StatefulWidget {
  /// Creates a [PerformanceScreenWrapper] with the given [screenName] and
  /// [child]
  const PerformanceScreenWrapper({
    required this.screenName,
    required this.child,
    this.performanceService,
    this.screenRoute,
    super.key,
  });

  /// The name of the screen for performance tracking
  final String screenName;

  /// The route name of the screen (optional)
  final String? screenRoute;

  /// The child widget to wrap
  final Widget child;

  /// Optional performance service (if not provided, will use NoOp)
  final IPerformanceService? performanceService;

  @override
  State<PerformanceScreenWrapper> createState() =>
      _PerformanceScreenWrapperState();
}

class _PerformanceScreenWrapperState extends State<PerformanceScreenWrapper> {
  IPerformanceTrace? _screenTrace;
  late IPerformanceService _performanceService;

  @override
  void initState() {
    super.initState();
    _performanceService =
        widget.performanceService ?? _NoOpPerformanceServiceInline();
    _startScreenTrace();
  }

  @override
  void dispose() {
    _stopScreenTrace();
    super.dispose();
  }

  void _startScreenTrace() {
    if (!_performanceService.isEnabled) {
      return;
    }

    _screenTrace = _performanceService.startScreenTrace(widget.screenName);
    if (_screenTrace != null) {
      _screenTrace!.putAttribute(
        PerformanceAttributes.screenName,
        widget.screenName,
      );
      if (widget.screenRoute != null) {
        _screenTrace!.putAttribute(
          PerformanceAttributes.screenRoute,
          widget.screenRoute!,
        );
      }
      _screenTrace!.startSync();
    }
  }

  void _stopScreenTrace() {
    if (_screenTrace != null) {
      _screenTrace!.putMetric(PerformanceMetrics.success, 1);
      _screenTrace!.stopSync();
      _screenTrace = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Private inline NoOp fallback (avoids circular import)
class _NoOpPerformanceServiceInline implements IPerformanceService {
  @override
  bool get isEnabled => false;
  @override
  IPerformanceTrace? startTrace(String name) => null;
  @override
  Future<T> measureOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  }) => operation();
  @override
  T measureSyncOperation<T>({
    required String name,
    required T Function() operation,
    Map<String, String>? attributes,
  }) => operation();
  @override
  T measureSyncComputation<T>({
    required String operationName,
    required T Function() computation,
    Map<String, String>? attributes,
  }) => computation();
  @override
  IPerformanceTrace? startHttpTrace(String method, String path) => null;
  @override
  IPerformanceTrace? startScreenTrace(String screenName) => null;
}
