import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/logging/uncaught_error_handlers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real NetworkImage diagnostics survive exception-only sanitization', () {
    final originalHandler = FlutterError.onError;
    FlutterErrorDetails? received;
    FlutterError.onError = (details) => received = details;
    final restore = installUncaughtErrorHandlers(LoggingService(enableLogging: false));
    try {
      const url = 'https://user:pass@cdn.example/a.png?token=REVIEW_SECRET';
      const image = NetworkImage(url);
      FlutterError.reportError(FlutterErrorDetails(
        exception: NetworkImageLoadException(statusCode: 403, uri: Uri.parse(url)),
        stack: StackTrace.current,
        library: 'image resource service',
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', image),
          DiagnosticsProperty<NetworkImage>('Image key', image),
        ],
      ));
      expect(received!.exception.toString(), isNot(contains('REVIEW_SECRET')));
      expect(received!.toString(), isNot(contains('REVIEW_SECRET')));
      print('FIX VERIFIED: mirrored NetworkImage diagnostics redact secret.');
    } finally {
      restore();
      FlutterError.onError = originalHandler;
    }
  });
  testWidgets('actual Image.network failure collector reaches previous handler', (tester) async {
    final originalHandler = FlutterError.onError;
    final received = <FlutterErrorDetails>[];
    FlutterError.onError = received.add;
    final restore = installUncaughtErrorHandlers(LoggingService(enableLogging: false));
    try {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Image(image: NetworkImage('https://cdn.example/a.png?token=ACTUAL_SECRET')),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(received, isNotEmpty);
      final details = received.first;
      expect(details.exception.toString(), isNot(contains('ACTUAL_SECRET')));
      expect(details.toString(), isNot(contains('ACTUAL_SECRET')));
      print('ACTUAL_IMAGE_DETAILS: ${details.toString()}');
    } finally {
      restore();
      FlutterError.onError = originalHandler;
    }
  });
  test('non-root relative request path remains unsanitized', () {
    final saved = FlutterError.onError;
    FlutterErrorDetails? received;
    FlutterError.onError = (details) => received = details;
    final restore = installUncaughtErrorHandlers(LoggingService(enableLogging: false));
    try {
      final error = StateError('GET verify?token=NOSLASH_SECRET failed');
      FlutterError.reportError(FlutterErrorDetails(exception: error));
      expect(received!.exception, isNot(same(error)));
      expect(received!.exception.toString(), isNot(contains('NOSLASH_SECRET')));
      print('FIX VERIFIED: no-leading-slash relative path redacted.');
    } finally {
      restore();
      FlutterError.onError = saved;
    }
  });
}
