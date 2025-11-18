import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_providers.dart';
import 'package:flutter_starter/core/performance/performance_screen_mixin.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
import 'package:flutter_starter/core/performance/performance_utils.dart';
import 'package:flutter_starter/core/utils/result.dart';

/// Examples of using performance monitoring in different scenarios
///
/// This file demonstrates how to integrate performance monitoring into:
/// - API calls
/// - Database queries
/// - Heavy computations
/// - Screen load time tracking
/// - Repository operations
/// - Use case operations

// ============================================================================
// Example 1: API Call Tracing
// ============================================================================

/// Example of measuring API call performance
///
/// This example shows how to measure an API call using the performance service.
Future<Map<String, dynamic>> exampleApiCallTracing(
  PerformanceService performanceService,
) async {
    return performanceService.measureApiCall<Map<String, dynamic>>(
    method: 'GET',
    path: '/users',
    call: () async {
      // Simulate API call
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return <String, dynamic>{'users': <dynamic>[]};
    },
    attributes: {
      PerformanceAttributes.userId: 'user123',
    },
  );
}

// ============================================================================
// Example 2: Database Query Tracing
// ============================================================================

/// Example of measuring database query performance
///
/// This example shows how to measure a database query using the performance
/// service.
Future<List<Map<String, dynamic>>> exampleDatabaseQueryTracing(
  PerformanceService performanceService,
) async {
    return performanceService.measureDatabaseQuery<List<Map<String, dynamic>>>(
    queryName: 'get_users',
    query: () async {
      // Simulate database query
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'User 1'},
        <String, dynamic>{'id': '2', 'name': 'User 2'},
      ];
    },
    attributes: {
      PerformanceAttributes.queryType: 'select',
    },
  );
}

// ============================================================================
// Example 3: Heavy Computation Tracing
// ============================================================================

/// Example of measuring heavy computation performance
///
/// This example shows how to measure a heavy computation using the performance
/// service.
Future<String> exampleHeavyComputationTracing(
  PerformanceService performanceService,
) async {
    return performanceService.measureComputation<String>(
    operationName: 'image_processing',
    computation: () async {
      // Simulate heavy computation
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      return 'processed_image.jpg';
    },
    attributes: {
      PerformanceAttributes.itemCount: '1',
    },
  );
}

/// Example of measuring sync computation performance
String exampleSyncComputationTracing(
  PerformanceService performanceService,
) {
  return performanceService.measureSyncComputation<String>(
    operationName: 'json_parsing',
    computation: () {
      // Simulate sync computation
      return 'parsed_data';
    },
    attributes: {
      PerformanceAttributes.itemCount: '100',
    },
  );
}

// ============================================================================
// Example 4: Screen Load Time Tracking
// ============================================================================

/// Example screen using PerformanceScreenMixin
///
/// This example shows how to use the PerformanceScreenMixin to automatically
/// track screen load times.
class ExampleScreenWithPerformance extends StatefulWidget {
  /// Creates an [ExampleScreenWithPerformance] widget
  const ExampleScreenWithPerformance({super.key});

  @override
  State<ExampleScreenWithPerformance> createState() =>
      _ExampleScreenWithPerformanceState();
}

class _ExampleScreenWithPerformanceState
    extends State<ExampleScreenWithPerformance> with PerformanceScreenMixin {
  @override
  String get screenName => 'example_screen';

  @override
  String? get screenRoute => '/example';

  @override
  PerformanceService? get performanceService {
    // Get from provider or context
    return null; // In real usage, get from provider
  }

  @override
  void initState() {
    super.initState();
    // Load data and mark screen as loaded when ready
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    // Simulate data loading
    await Future<void>.delayed(const Duration(milliseconds: 500));
    markScreenLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Example Screen')),
      body: const Center(child: Text('Example Screen Content')),
    );
  }
}

/// Example screen using PerformanceScreenWrapper
///
/// This example shows how to use the PerformanceScreenWrapper widget to
/// automatically track screen load times without using mixins.
class ExampleScreenWithWrapper extends ConsumerWidget {
  /// Creates an [ExampleScreenWithWrapper] widget
  const ExampleScreenWithWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceService = ref.read(performanceServiceProvider);

    return PerformanceScreenWrapper(
      screenName: 'example_screen_wrapper',
      screenRoute: '/example-wrapper',
      performanceService: performanceService,
      child: Scaffold(
        appBar: AppBar(title: const Text('Example Screen')),
        body: const Center(child: Text('Example Screen Content')),
      ),
    );
  }
}

// ============================================================================
// Example 5: Repository Operation Tracing
// ============================================================================

/// Example repository using PerformanceRepositoryMixin
///
/// This example shows how to use the PerformanceRepositoryMixin to track
/// repository operations.
abstract class ExampleRepository {
  /// Get all items
  Future<Result<List<String>>> getItems();

  /// Get item by ID
  Future<Result<String?>> getItemById(String id);
}

/// Implementation of [ExampleRepository]
///
/// This class demonstrates how to use performance monitoring in repository
/// implementations.
class ExampleRepositoryImpl implements ExampleRepository {
  /// Creates an [ExampleRepositoryImpl] with the given [performanceService]
  ExampleRepositoryImpl({
    required this.performanceService,
  });

  /// Performance service for tracking repository operations
  final PerformanceService performanceService;

  @override
  Future<Result<List<String>>> getItems() {
    // In real usage, you would use the mixin:
    // class ExampleRepositoryImpl with PerformanceRepositoryMixin
    //   implements ExampleRepository
    // Then call: return measureDataFetch<List<String>>(...)
    
    // For this example, we'll use the service directly
    return performanceService.measureOperation<Result<List<String>>>(
      name: 'repository_get_items',
      operation: () async {
        // Simulate repository operation
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return const Success<List<String>>(['item1', 'item2', 'item3']);
      },
      attributes: {
        PerformanceAttributes.operationName: 'get_items',
        PerformanceAttributes.queryType: 'fetch',
        PerformanceAttributes.recordCount: '3',
      },
    );
  }

  @override
  Future<Result<String?>> getItemById(String id) {
    return performanceService.measureOperation<Result<String?>>(
      name: 'repository_get_item_by_id',
      operation: () async {
        // Simulate repository operation
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return Success<String?>('item_$id');
      },
      attributes: {
        PerformanceAttributes.operationName: 'get_item_by_id',
        PerformanceAttributes.queryType: 'fetch',
      },
    );
  }
}

// ============================================================================
// Example 6: Use Case Operation Tracing
// ============================================================================

/// Example use case using PerformanceUseCaseMixin
///
/// This example shows how to use the PerformanceUseCaseMixin to track use case
/// operations.
///
/// Note: In real usage, you would use:
/// ```dart
/// class GetItemsUseCase with PerformanceUseCaseMixin {
///   @override
///   PerformanceService? get performanceService => _performanceService;
///   // ... rest of implementation
/// }
/// ```
class GetItemsUseCase {
  /// Creates a [GetItemsUseCase] with the given [repository] and optional
  /// [performanceService]
  GetItemsUseCase({
    required this.repository,
    this.performanceService,
  });

  /// Repository for fetching items
  final ExampleRepository repository;

  /// Optional performance service for tracking use case operations
  final PerformanceService? performanceService;

  /// Executes the use case to get all items
  Future<Result<List<String>>> call() {
    // In real usage with the mixin, you would call:
    // return measureUseCaseOperation<List<String>>(...)
    
    // For this example, we'll use the service directly
    if (performanceService == null || !performanceService!.isEnabled) {
      return repository.getItems();
    }

    return performanceService!.measureOperation<Result<List<String>>>(
      name: 'usecase_get_items',
      operation: repository.getItems,
      attributes: {
        PerformanceAttributes.operationName: 'get_items',
        PerformanceAttributes.operationType: 'usecase',
        PerformanceAttributes.featureName: 'items',
      },
    );
  }
}

// ============================================================================
// Example 7: Custom Trace with Metrics
// ============================================================================

/// Example of creating a custom trace with metrics
///
/// This example shows how to create a custom trace and record metrics manually.
Future<void> exampleCustomTrace(PerformanceService performanceService) async {
  final trace = performanceService.startTrace('custom_operation');
  if (trace == null) return;

  try {
    await trace.start();

    // Add attributes
    trace
      ..putAttribute(PerformanceAttributes.operationName, 'custom_op')
      ..putAttribute(PerformanceAttributes.userId, 'user123');

    // Perform operation
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Record metrics
    trace
      ..putMetric(PerformanceMetrics.itemsProcessed, 10)
      ..putMetric(PerformanceMetrics.success, 1);
  } catch (e) {
    trace
      ..putMetric(PerformanceMetrics.error, 1)
      ..putAttribute(
        PerformanceAttributes.errorType,
        e.runtimeType.toString(),
      );
    rethrow;
  } finally {
    await trace.stop();
  }
}

// ============================================================================
// Example 8: Using PerformanceUtils
// ============================================================================

/// Example of using PerformanceUtils convenience methods
Future<void> exampleUsingPerformanceUtils(
  PerformanceService performanceService,
) async {
  // Measure API call
  await PerformanceUtils.measureApiCall(
    service: performanceService,
    method: 'POST',
    path: '/users',
    call: () async {
      // API call
      await Future<void>.delayed(const Duration(milliseconds: 300));
    },
  );

  // Measure database query
  await PerformanceUtils.measureDatabaseQuery(
    service: performanceService,
    queryName: 'get_user_by_id',
    query: () async {
      // Database query
      await Future<void>.delayed(const Duration(milliseconds: 100));
    },
  );

  // Measure computation
  await PerformanceUtils.measureComputation(
    service: performanceService,
    operationName: 'process_data',
    computation: () async {
      // Heavy computation
      await Future<void>.delayed(const Duration(milliseconds: 800));
    },
  );
}
