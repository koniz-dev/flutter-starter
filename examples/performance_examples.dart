import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_providers.dart';
import 'package:flutter_starter/core/performance/performance_screen_mixin.dart';
import 'package:flutter_starter/core/performance/performance_utils.dart';
import 'package:flutter_starter/core/utils/result.dart';

/// Reference snippets for `IPerformanceService`.
///
/// Extension methods (`measureApiCall`, etc.) mirror `PerformanceUtils` —
/// pick one style per call site. Not imported from `main.dart`.

Future<void> _simDelay(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

// --- API / DB / CPU (extension on service; requires `performance_utils` import)

Future<Map<String, dynamic>> exampleApiCallTracing(
  IPerformanceService performanceService,
) async {
  return performanceService.measureApiCall<Map<String, dynamic>>(
    method: 'GET',
    path: '/users',
    call: () async {
      await _simDelay(500);
      return <String, dynamic>{'users': <dynamic>[]};
    },
    attributes: {PerformanceAttributes.userId: 'user123'},
  );
}

Future<List<Map<String, dynamic>>> exampleDatabaseQueryTracing(
  IPerformanceService performanceService,
) async {
  return performanceService.measureDatabaseQuery<List<Map<String, dynamic>>>(
    queryName: 'get_users',
    query: () async {
      await _simDelay(200);
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': '1', 'name': 'User 1'},
        <String, dynamic>{'id': '2', 'name': 'User 2'},
      ];
    },
    attributes: {PerformanceAttributes.queryType: 'select'},
  );
}

Future<String> exampleHeavyComputationTracing(
  IPerformanceService performanceService,
) async {
  return performanceService.measureComputation<String>(
    operationName: 'image_processing',
    computation: () async {
      await _simDelay(1000);
      return 'processed_image.jpg';
    },
    attributes: {PerformanceAttributes.itemCount: '1'},
  );
}

String exampleSyncComputationTracing(IPerformanceService performanceService) {
  return performanceService.measureSyncComputation<String>(
    operationName: 'json_parsing',
    computation: () => 'parsed_data',
    attributes: {PerformanceAttributes.itemCount: '100'},
  );
}

// --- Screens

class ExampleScreenWithPerformance extends StatefulWidget {
  const ExampleScreenWithPerformance({super.key});

  @override
  State<ExampleScreenWithPerformance> createState() =>
      _ExampleScreenWithPerformanceState();
}

class _ExampleScreenWithPerformanceState
    extends State<ExampleScreenWithPerformance>
    with PerformanceScreenMixin {
  @override
  String get screenName => 'example_screen';

  @override
  String? get screenRoute => '/example';

  @override
  IPerformanceService? get performanceService => null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    await _simDelay(500);
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

class ExampleScreenWithWrapper extends ConsumerWidget {
  const ExampleScreenWithWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfService = ref.read(performanceServiceProvider);

    return PerformanceScreenWrapper(
      screenName: 'example_screen_wrapper',
      screenRoute: '/example-wrapper',
      performanceService: perfService,
      child: Scaffold(
        appBar: AppBar(title: const Text('Example Screen')),
        body: const Center(child: Text('Example Screen Content')),
      ),
    );
  }
}

// --- Repository / use case

abstract class ExampleRepository {
  Future<Result<List<String>>> getItems();
  Future<Result<String?>> getItemById(String id);
}

class ExampleRepositoryImpl implements ExampleRepository {
  ExampleRepositoryImpl({required this.performanceService});

  final IPerformanceService performanceService;

  @override
  Future<Result<List<String>>> getItems() {
    return performanceService.measureOperation<Result<List<String>>>(
      name: 'repository_get_items',
      operation: () async {
        await _simDelay(300);
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
        await _simDelay(200);
        return Success<String?>('item_$id');
      },
      attributes: {
        PerformanceAttributes.operationName: 'get_item_by_id',
        PerformanceAttributes.queryType: 'fetch',
      },
    );
  }
}

class GetItemsUseCase {
  GetItemsUseCase({required this.repository, this.performanceService});

  final ExampleRepository repository;
  final IPerformanceService? performanceService;

  Future<Result<List<String>>> call() {
    final perf = performanceService;
    if (perf == null || !perf.isEnabled) {
      return repository.getItems();
    }
    return perf.measureOperation<Result<List<String>>>(
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

// --- Custom trace

Future<void> exampleCustomTrace(IPerformanceService performanceService) async {
  final trace = performanceService.startTrace('custom_operation');
  if (trace == null) return;

  try {
    await trace.start();
    trace
      ..putAttribute(PerformanceAttributes.operationName, 'custom_op')
      ..putAttribute(PerformanceAttributes.userId, 'user123');

    await _simDelay(500);

    trace
      ..putMetric(PerformanceMetrics.itemsProcessed, 10)
      ..putMetric(PerformanceMetrics.success, 1);
  } catch (e) {
    trace
      ..putMetric(PerformanceMetrics.error, 1)
      ..putAttribute(PerformanceAttributes.errorType, e.runtimeType.toString());
    rethrow;
  } finally {
    await trace.stop();
  }
}

// --- One-shot: static helpers (same traces as extension methods above)

Future<void> examplePerformanceUtilsBatch(
  IPerformanceService performanceService,
) async {
  await PerformanceUtils.measureApiCall(
    service: performanceService,
    method: 'POST',
    path: '/users',
    call: () => _simDelay(300),
  );
  await PerformanceUtils.measureDatabaseQuery(
    service: performanceService,
    queryName: 'get_user_by_id',
    query: () => _simDelay(100),
  );
  await PerformanceUtils.measureComputation(
    service: performanceService,
    operationName: 'process_data',
    computation: () => _simDelay(800),
  );
}
