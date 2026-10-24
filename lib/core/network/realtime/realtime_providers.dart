import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/noop_realtime_client.dart';

/// Provider for the base real-time client.
/// By default it is a no-op client, so the app opens no socket until you
/// choose a real-time backend.
/// Override this provider to inject `RawWebSocketClientImpl` for production.
final realtimeClientProvider = Provider<IRealtimeClient>((ref) {
  return NoOpRealtimeClient();
});
