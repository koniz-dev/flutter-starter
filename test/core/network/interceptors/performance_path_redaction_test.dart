// A performance trace leaves the device like a log line does, so the request
// path it records goes through the same redaction as the logs:
// `get('/verify?token=X')` is a normal call.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPerformanceService extends Mock implements IPerformanceService {}

class _MockPerformanceTrace extends Mock implements IPerformanceTrace {}

class _Handler extends RequestInterceptorHandler {}

const _path = '/verify?token=SECRET&page=2';

void main() {
  late _MockPerformanceService service;
  late _MockPerformanceTrace trace;
  late List<String> traceNames;
  late Map<String, String> attributes;

  setUp(() {
    service = _MockPerformanceService();
    trace = _MockPerformanceTrace();
    traceNames = [];
    attributes = {};
    when(() => service.startHttpTrace(any(), any())).thenAnswer((call) {
      traceNames.add(call.positionalArguments[1] as String);
      return trace;
    });
    when(() => trace.putAttribute(any(), any())).thenAnswer((call) {
      attributes[call.positionalArguments[0] as String] =
          call.positionalArguments[1] as String;
    });
    when(() => trace.startSync()).thenReturn(null);
  });

  test('no trace name or attribute carries the secret', () {
    PerformanceInterceptor(
      performanceService: service,
    ).onRequest(RequestOptions(path: _path), _Handler());

    expect(traceNames.single, isNot(contains('SECRET')));
    for (final value in attributes.values) {
      expect(value, isNot(contains('SECRET')));
    }
  });

  test('the recorded path is the one the logs show', () {
    PerformanceInterceptor(
      performanceService: service,
    ).onRequest(RequestOptions(path: _path), _Handler());

    final logged = ApiLoggingInterceptor.redactPath(_path);
    expect(attributes[PerformanceAttributes.httpPath], logged);
    expect(traceNames.single, logged);
    // A parameter that names no secret is kept, as in the logs.
    expect(logged, contains('page=2'));
  });

  test('the Firebase template redacts the http_path it sends', () {
    final template = File(
      'lib/core/performance/infrastructure/'
      'firebase_performance_service.dart.template',
    ).readAsStringSync();

    expect(
      template,
      contains("putAttribute('http_path', ApiLoggingInterceptor.redactPath("),
    );
    expect(template, isNot(contains("putAttribute('http_path', path)")));
  });
}
