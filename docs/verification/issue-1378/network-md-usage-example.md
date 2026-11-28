### Usage Example

The client is per session, so take it from a provider that watches it: when
the session changes, Riverpod rebuilds this provider with the new client and
the old one is already disconnected. Connect only while signed in.

```dart
@riverpod
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
```

`connect` fails when the host is unreachable or refuses the connection (an
offline launch, for example), when the handshake times out, and when a
session change disconnects the client while it is still connecting. Route
the error to the same retry policy as a `RealtimeConnectionClosed`, and
retry only while signed in: after a session change, the rebuilt provider
connects the new session's client itself.

The calls on a client, wherever you hold it:
