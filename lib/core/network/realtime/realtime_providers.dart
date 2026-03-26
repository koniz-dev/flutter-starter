import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/noop_realtime_client.dart';

/// Provider for the base real-time client.
/// By default, it uses a NoOp client since this is a Starter.
/// Override this provider to inject `RawWebSocketClientImpl` for production.
final realtimeClientProvider = Provider<IRealtimeClient>((ref) {
  return NoOpRealtimeClient();
});
