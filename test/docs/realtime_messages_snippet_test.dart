// docs/api/core/network.md shows a `realtimeMessages` provider that starts
// the connection without awaiting it. A failed connect adds nothing to the
// client's stream and surfaces only through connect's future, so an example
// that dropped that future turned every offline launch into an uncaught
// error. The function below is the documented one, quoted line for line, and
// it is run against a refused port.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/realtime/realtime_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// The app-supplied callbacks the documented provider calls.
bool isSignedIn(Ref ref) => true;

final List<Object> _connectErrors = [];

void handleRealtimeConnectError(Object error) => _connectErrors.add(error);

// BEGIN realtimeMessages
Stream<dynamic> realtimeMessages(Ref ref) {
  final realtimeClient = ref.watch(realtimeClientProvider);
  // Your app's signed-in check; connect as the current user only.
  if (!isSignedIn(ref)) return const Stream.empty();
  // A failed connect adds nothing to the stream: its error arrives only
  // through this future, so leaving it unhandled makes it an uncaught error.
  unawaited(
    realtimeClient
        .connect('wss://example.com/socket')
        .catchError(handleRealtimeConnectError),
  );
  return realtimeClient.stream;
}
// END realtimeMessages

/// The body of the doc's `@riverpod` block that declares `realtimeMessages`,
/// from its signature to its closing brace.
String _documented(String markdown) {
  final match = RegExp(
    r'```dart\n@riverpod\n(Stream<dynamic> realtimeMessages\(.*?\n\})\n```',
    dotAll: true,
  ).firstMatch(markdown);
  expect(match, isNotNull, reason: 'realtimeMessages example not found');
  return match!.group(1)!;
}

/// The function between the BEGIN/END markers in this file.
String _quoted(String source) {
  final match = RegExp(
    r'// BEGIN realtimeMessages\n(.*?)\n// END realtimeMessages',
    dotAll: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'BEGIN/END markers not found');
  return match!.group(1)!;
}

void main() {
  test('network.md quotes realtimeMessages as this test runs it', () {
    final doc = File('docs/api/core/network.md').readAsStringSync();
    final source = File(
      'test/docs/realtime_messages_snippet_test.dart',
    ).readAsStringSync();

    expect(_documented(doc), _quoted(source));
  });

  test('the documented realtimeMessages leaves no uncaught error when the '
      'connection is refused', () async {
    // Reserve a free port, then release it so nothing listens there.
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final refused = Uri.parse('ws://127.0.0.1:${socket.port}/socket');
    await socket.close();

    _connectErrors.clear();
    final zoneErrors = <Object>[];
    final streamEvents = <Object?>[];
    final done = Completer<void>();

    Future<void> run() async {
      final container = ProviderContainer(
        overrides: [
          realtimeClientFactoryProvider.overrideWithValue(
            () => RawWebSocketClientImpl(
              // The documented URL is a placeholder: send it to the
              // refused port instead of the network.
              connectChannel: (_, _) => WebSocketChannel.connect(refused),
            ),
          ),
        ],
      );
      final messages = StreamProvider<dynamic>(realtimeMessages);
      try {
        final sub = container.listen(
          messages,
          (_, next) => streamEvents.add(next),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (_connectErrors.isEmpty && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        // Give a stray async error from the attempt time to reach the zone.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        sub.close();
      } finally {
        container.dispose();
        done.complete();
      }
    }

    runZonedGuarded(
      () => unawaited(run()),
      (error, _) => zoneErrors.add(error),
    );
    await done.future;

    expect(zoneErrors, isEmpty);
    expect(_connectErrors, [isA<WebSocketChannelException>()]);
    expect(streamEvents, isEmpty);
  });
}
