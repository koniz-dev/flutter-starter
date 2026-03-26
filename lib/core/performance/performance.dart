/// Performance monitoring module
///
/// This module provides comprehensive performance monitoring capabilities
/// with a pluggable backend architecture.
///
/// ## Default Behavior
///
/// By default, the module uses [NoOpPerformanceService] which does nothing
/// and has zero external dependencies. This means your app runs without
/// any performance monitoring overhead by default.
///
/// ## Enabling Firebase Performance
///
/// To enable Firebase Performance monitoring, override the provider:
///
/// ```dart
/// final performanceServiceProvider = Provider<IPerformanceService>((ref) {
///   return FirebasePerformanceService();
/// });
/// ```
///
/// ## Features
///
/// - Automatic HTTP request tracking via interceptor
/// - Custom trace creation and management
/// - Screen load time tracking
/// - Repository and use case operation tracking
/// - Database query performance tracking
/// - Heavy computation performance tracking
///
/// ## Usage
///
/// ### Basic Usage
///
/// ```dart
/// final performanceService = ref.watch(performanceServiceProvider);
/// final trace = performanceService.startTrace('my_operation');
/// await trace?.start();
/// // ... perform operation ...
/// await trace?.stop();
/// ```
///
/// ### Automatic API Tracking
///
/// The API client automatically tracks all HTTP requests when performance
/// monitoring is enabled. No additional code is needed.
///
/// ### Screen Performance Tracking
///
/// ```dart
/// class MyScreen extends StatefulWidget {
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends State<MyScreen> with PerformanceScreenMixin {
///   @override
///   String get screenName => 'my_screen';
/// }
/// ```
///
/// See `examples/performance_examples.dart` for more examples.
library;

import 'package:flutter_starter/core/performance/noop_performance_service.dart'
    show NoOpPerformanceService;

export 'package:flutter_starter/core/performance/i_performance_service.dart';
export 'package:flutter_starter/core/performance/noop_performance_service.dart';
export 'package:flutter_starter/core/performance/performance_attributes.dart';
export 'package:flutter_starter/core/performance/performance_providers.dart';
export 'package:flutter_starter/core/performance/performance_repository_mixin.dart';
export 'package:flutter_starter/core/performance/performance_screen_mixin.dart';

export 'package:flutter_starter/core/performance/performance_usecase_mixin.dart';
export 'package:flutter_starter/core/performance/performance_utils.dart';
