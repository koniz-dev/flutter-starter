// ImageCacheHelper.preloadImage debugPrinted the image URL - a presigned
// signature or a ?token= - and the load error, whose text quotes the URL, on
// its timeout and error paths. debugPrint prints in release builds too.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/image_cache_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> printed;
  late DebugPrintCallback previous;

  setUp(() {
    // Real loopback connections; the test binding answers every request 400.
    HttpOverrides.global = null;
    printed = [];
    previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add('$message');
    imageCache.clear();
  });

  String urlOn(int port) =>
      'http://user:pass@127.0.0.1:$port/a.png'
      '?X-Amz-Signature=SECRET&token=T2';

  /// Restores debugPrint - inside the test body, before the binding checks
  /// its debug variables - then checks what was printed.
  void expectRedacted() {
    debugPrint = previous;
    final text = printed.join('\n');
    expect(printed, isNotEmpty);
    for (final secret in ['pass', 'SECRET', 'T2']) {
      expect(text, isNot(contains(secret)), reason: secret);
    }
  }

  /// A server that accepts and does not answer until [release]d.
  Future<({int port, Future<void> Function() release})> silent() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final held = <Socket>[];
    server.listen(held.add);
    Future<void> release() async {
      for (final socket in held) {
        socket.destroy();
      }
      await server.close();
    }

    return (port: server.port, release: release);
  }

  /// Ends a timed-out load inside the test: the abandoned request then fails,
  /// and with no listener left the image cache reports that to FlutterError,
  /// which here is expected and dropped.
  Future<void> releaseQuietly(Future<void> Function() release) async {
    final onError = FlutterError.onError;
    FlutterError.onError = (_) {};
    await release();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    FlutterError.onError = onError;
  }

  /// A server that answers 403 to everything.
  Future<HttpServer> forbidden() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 403;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    return server;
  }

  /// A widget's context, for the precacheImage path.
  Future<BuildContext> contextOf(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    return context;
  }

  for (final withContext in [false, true]) {
    final variant = withContext ? 'with a context' : 'without a context';

    testWidgets('$variant, the timeout path prints no secret', (tester) async {
      final context = withContext ? await contextOf(tester) : null;
      await tester.runAsync(() async {
        final hang = await silent();
        await ImageCacheHelper.preloadImage(
          urlOn(hang.port),
          context: context,
          timeout: const Duration(milliseconds: 300),
        );
        await releaseQuietly(hang.release);
      });

      expectRedacted();
      expect(printed.join('\n'), contains('timed out'));
    });

    testWidgets('$variant, the error path prints no secret', (tester) async {
      final context = withContext ? await contextOf(tester) : null;
      await tester.runAsync(() async {
        final refuse = await forbidden();
        await ImageCacheHelper.preloadImage(
          urlOn(refuse.port),
          context: context,
          timeout: const Duration(seconds: 5),
        );
      });

      expectRedacted();
      expect(printed.join('\n'), contains('403'));
    });
  }
}
