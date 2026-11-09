import 'package:flutter_starter/core/performance/noop_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder extends NoOpPerformanceService {
  String? name;
  Map<String, String>? attributes;
  int traces = 0;
  @override
  Future<T> measureOperation<T>({required String name, required Future<T> Function() operation, Map<String, String>? attributes}) {
    traces++;
    this.name = name;
    this.attributes = attributes;
    return operation();
  }
}

void main() {
  test('independent: original operation errors propagate without another trace', () async {
    final recorder = _Recorder();
    final error = StateError('synthetic operation failure');
    await expectLater(PerformanceUtils.measureApiCall<int>(service: recorder, method: 'POST', path: '/users/1?token=synthetic', call: () async => throw error), throwsA(same(error)));
    expect(recorder.traces, 1);
    expect(recorder.attributes?['http_path'], '/users/1?token=***REDACTED***');
  });
  test('independent: scheme-relative encoded credentials are redacted', () async {
    final recorder = _Recorder();
    await PerformanceUtils.measureApiCall<bool>(service: recorder, method: 'GET', path: '//fixture_name:P%40SS@api.example.test/verify?ACCESS_TOKEN=encodedSecret', call: () async => true);
    for (final value in [recorder.name!, ...recorder.attributes!.values]) {
      expect(value, isNot(contains('fixture_name')));
      expect(value, isNot(contains('P%40SS')));
      expect(value, isNot(contains('encodedSecret')));
    }
  });
  test('independent: canonical fields do not mutate supplied attributes', () async {
    final recorder = _Recorder();
    const path = '/verify?token=synthetic';
    final attributes = {'http_path': path, 'http_method': 'CUSTOM', 'component': 'test'};
    final result = await recorder.measureApiCall<String>(method: 'PUT', path: path, call: () async => 'typed result', attributes: attributes);
    expect(result, 'typed result');
    expect(attributes['http_path'], path);
    expect(attributes['http_method'], 'CUSTOM');
    expect(recorder.attributes?['http_method'], 'PUT');
    expect(recorder.attributes?['http_path'], '/verify?token=***REDACTED***');
    expect(recorder.attributes?['component'], 'test');
  });
}
