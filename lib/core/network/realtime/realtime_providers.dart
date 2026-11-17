import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/noop_realtime_client.dart';
import 'package:flutter_starter/core/session/session_providers.dart';

/// Factory for realtime clients owned by [realtimeClientProvider].
///
/// Override this factory to inject a backend while retaining automatic
/// disconnection when its owning provider is disposed.
final realtimeClientFactoryProvider = Provider<IRealtimeClient Function()>(
  (ref) => NoOpRealtimeClient.new,
);

/// Provider for the base real-time client.
/// By default it is a no-op client, so the app opens no socket until you
/// choose a real-time backend.
/// Override [realtimeClientFactoryProvider] to inject a production client.
/// Direct overrides of this provider own their cleanup themselves.
///
/// One client per session: a connection is usually authenticated as the
/// signed-in user, so logout, a forced logout and every sign-in
/// ([sessionEpochProvider]) disconnect it, and the next read gets a fresh
/// client to connect as the new user. Kept for the app's lifetime, user A's
/// socket stayed open through the next user's sign-in.
final realtimeClientProvider = Provider<IRealtimeClient>((ref) {
  ref.watch(sessionEpochProvider);
  final client = ref.watch(realtimeClientFactoryProvider)();
  ref.onDispose(client.disconnect);
  return client;
});
