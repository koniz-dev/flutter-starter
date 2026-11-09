import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/noop_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/realtime/realtime_providers.dart';
import 'package:flutter_test/flutter_test.dart';

class _Owned extends NoOpRealtimeClient {
  int disconnects = 0;
  @override void disconnect() { disconnects++; }
}

void main() {
  test('independent: a subscriber survives remote close and reconnect', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peers = <WebSocket>[];
    final firstAccepted=Completer<WebSocket>();
    final secondAccepted=Completer<WebSocket>();
    server.transform(WebSocketTransformer()).listen((socket) {
      peers.add(socket);
      if (peers.length == 1) firstAccepted.complete(socket); else secondAccepted.complete(socket);
    });
    final client=RawWebSocketClientImpl();
    final errors=<Object>[];
    final states=<bool>[];
    final firstData=Completer<void>(); final secondData=Completer<void>(); final firstClose=Completer<void>();
    final sub=client.stream.listen((dynamic value) {
      if(value=='first') firstData.complete();
      if(value=='second') secondData.complete();
    },onError:(Object error) {
      errors.add(error); states.add(client.isConnected);
      if(!firstClose.isCompleted) firstClose.complete();
    });
    try {
      final url='ws://127.0.0.1:${server.port}';
      await client.connect(url); final first=await firstAccepted.future; first.add('first');
      await firstData.future.timeout(const Duration(seconds:5));
      await first.close(1001); await firstClose.future.timeout(const Duration(seconds:5));
      expect(errors.single,isA<RealtimeConnectionClosed>()); expect(states,[false]);
      await client.connect(url); final second=await secondAccepted.future; second.add('second');
      await secondData.future.timeout(const Duration(seconds:5)); expect(client.isConnected,isTrue);
      client.disconnect(); await pumpEventQueue(); expect(errors.length,1);
    } finally { client.disconnect(); await sub.cancel(); await server.close(force:true); }
  });

  test('independent: replacing factory disconnects old provider-owned instance', () async {
    final firstClient=_Owned(); final secondClient=_Owned();
    final container=ProviderContainer(overrides:[realtimeClientFactoryProvider.overrideWithValue(() => firstClient)]);
    final first=container.read(realtimeClientProvider);
    container.updateOverrides([realtimeClientFactoryProvider.overrideWithValue(() => secondClient)]);
    await container.pump();
    final second=container.read(realtimeClientProvider);
    expect(identical(first,second),isFalse); expect(firstClient.disconnects,1);
    container.dispose(); expect(firstClient.disconnects,1);expect(secondClient.disconnects,1);
  });
}
