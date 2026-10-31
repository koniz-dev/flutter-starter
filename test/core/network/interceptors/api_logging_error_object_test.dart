// ApiLoggingInterceptor.onError redacted its message and context but passed
// the raw DioException to the logger and the error reporter. Its toString
// ends with the underlying dart:io HttpException, whose text ends with
// `, uri = <the full URI>` - every query secret and the userinfo included.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _RecordingReporter implements IErrorReporter {
  final reports = <String>[];

  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    reports.add('$message | $error | $context');
  }
}

class _RecordingOutput extends LogOutput {
  final lines = <String>[];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

void main() {
  test('a failed request reaches neither the log nor the reporter with its '
      'query secrets or userinfo', () async {
    // Accepts a connection and closes it before any response header.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());

    final reporter = _RecordingReporter();
    final output = _RecordingOutput();
    final logging = LoggingService(
      enableLogging: true,
      enableFileLogging: false,
      errorReporter: reporter,
      output: output,
    );
    final dio = Dio()
      ..interceptors.add(ApiLoggingInterceptor(loggingService: logging));

    await expectLater(
      dio.get<void>(
        'http://usr1:pw1@127.0.0.1:${server.port}/callback'
        '?code=SECRET1&access_token=SECRET2&page=3',
      ),
      throwsA(isA<DioException>()),
    );
    // Reporting is fire-and-forget.
    await Future<void>.delayed(Duration.zero);

    final everything = [...output.lines, ...reporter.reports].join('\n');
    expect(reporter.reports, isNotEmpty);
    for (final secret in ['SECRET1', 'SECRET2', 'usr1', 'pw1']) {
      expect(everything, isNot(contains(secret)), reason: secret);
    }
    // What is left stays useful.
    expect(everything, contains('HttpException'));
    // The reason survives, in the platform's wording: dart:io reports a
    // socket closed before the response as a close, or under load a reset.
    expect(
      everything,
      anyOf(contains('Connection closed'), contains('Connection reset')),
    );
    expect(everything, contains('page=3'));
  });
}
