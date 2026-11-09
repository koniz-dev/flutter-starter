import 'package:flutter_starter/core/performance/noop_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_utils.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder extends NoOpPerformanceService {
  String? name;
  Map<String, String>? attributes;

  @override
  Future<T> measureOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  }) {
    this.name = name;
    this.attributes = attributes;
    return operation();
  }
}

void main() {
  const absolute =
      'https://user:pa55@api.example.com/verify?token=SECRET123&page=2';
  const relative = '/verify?token=SECRET123&page=2';
  for (final (label, path, overridePath) in [
    ('absolute credentials', absolute, false),
    ('relative query', relative, false),
    ('reserved path override', absolute, true),
  ]) {
    test('API performance redacts $label', () async {
      final recorder = _Recorder();
      var calls = 0;
      final result = await PerformanceUtils.measureApiCall<int>(
        service: recorder,
        method: 'GET',
        path: path,
        call: () async => ++calls,
        additionalAttributes: {
          'component': 'verification',
          if (overridePath) 'http_path': path,
        },
      );
      expect(result, 1);
      expect(calls, 1);
      for (final recorded in [recorder.name!, ...recorder.attributes!.values]) {
        expect(recorded, isNot(contains('pa55')));
        expect(recorded, isNot(contains('SECRET123')));
      }
      final prefix = path.startsWith('https:')
          ? 'https://***REDACTED***@api.example.com'
          : '';
      expect(recorder.name, 'api_get_$prefix/verify');
      expect(recorder.attributes, {
        'component': 'verification',
        'http_method': 'GET',
        'http_path': '$prefix/verify?token=***REDACTED***&page=2',
      });
    });
  }

  test('plain API paths retain their recorded attributes', () async {
    final recorder = _Recorder();
    await PerformanceUtils.measureApiCall<int>(
      service: recorder,
      method: 'GET',
      path: '/users/1',
      call: () async => 7,
    );
    expect(recorder.name, 'api_get_/users/:id');
    expect(recorder.attributes, {
      'http_method': 'GET',
      'http_path': '/users/1',
    });
  });
}
