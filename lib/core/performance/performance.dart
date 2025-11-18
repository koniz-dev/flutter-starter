/// Performance monitoring module
///
/// This module provides comprehensive performance monitoring capabilities
/// using Firebase Performance Monitoring.
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
/// final performanceService = PerformanceService();
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
/// ### Repository Performance Tracking
///
/// ```dart
/// class MyRepositoryImpl
///     implements MyRepository with PerformanceRepositoryMixin {
///   @override
///   PerformanceService? get performanceService => _performanceService;
///
///   Future<Result<List<Item>>> getItems() {
///     return measureRepositoryOperation(
///       operationName: 'get_items',
///       operation: () => _fetchItems(),
///     );
///   }
/// }
/// ```
///
/// See `performance_examples.dart` for more examples.
library;

export 'package:flutter_starter/core/performance/performance_attributes.dart';
export 'package:flutter_starter/core/performance/performance_providers.dart';
export 'package:flutter_starter/core/performance/performance_repository_mixin.dart';
export 'package:flutter_starter/core/performance/performance_screen_mixin.dart';
export 'package:flutter_starter/core/performance/performance_service.dart';
export 'package:flutter_starter/core/performance/performance_usecase_mixin.dart';
export 'package:flutter_starter/core/performance/performance_utils.dart';
