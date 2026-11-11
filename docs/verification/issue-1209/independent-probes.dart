import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/adapters/dio_network_client.dart';
import 'package:flutter_starter/core/network/request_cancellation.dart';

class ProbeAdapter implements HttpClientAdapter {
  RequestOptions? seen;
  bool cancelled = false;
  final bool hang;
  ProbeAdapter({this.hang = false});
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancelFuture) async {
    seen = options;
    cancelFuture?.then((_) { cancelled = true; });
    if (hang) return Completer<ResponseBody>().future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return ResponseBody.fromString('ok', 200);
  }
  @override
  void close({bool force = false}) {}
}
void check(bool value, String label) { if (!value) throw StateError(label); }
Future<void> main() async {
  for (final duration in [Duration.zero, const Duration(seconds: -1)]) {
    for (final method in NetworkMethod.values) {
      final adapter = ProbeAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost', sendTimeout: const Duration(seconds: 7), receiveTimeout: const Duration(seconds: 8)))..httpClientAdapter = adapter;
      final client = DioNetworkClient(dio, deadline: duration);
      final response = await client.send(NetworkRequest(path: '/shape', method: method, body: method == NetworkMethod.get ? null : {'a': 1}, headers: {'X-Probe': 'yes'}, queryParameters: {'q': 'x'}, timeout: const Duration(seconds: 2)));
      check(response.statusCode == 200, 'response');
      check(adapter.seen!.sendTimeout == const Duration(seconds: 2), 'send per-request timeout');
      check(adapter.seen!.receiveTimeout == const Duration(seconds: 2), 'receive per-request timeout');
      check(adapter.seen!.headers['X-Probe'] == 'yes', 'headers');
      check(adapter.seen!.queryParameters['q'] == 'x', 'query');
      print('PASS disabled=$duration method=$method shapes/options');
      dio.close(force: true);
    }
    final adapter = ProbeAdapter(hang: true);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
    final cancellation = RequestCancellation();
    final pending = DioNetworkClient(dio, deadline: duration).send(const NetworkRequest(path: '/hang', method: NetworkMethod.get), cancellation: cancellation);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cancellation.cancel('probe');
    try { await pending.timeout(const Duration(seconds: 1)); throw StateError('cancellation did not fail'); }
    on NetworkError catch (e) { check(e.code == 'cancel', 'cancel code'); }
    check(adapter.cancelled, 'transport cancellation');
    print('PASS disabled=$duration caller cancellation reaches transport');
    dio.close(force: true);
  }
  final adapter = ProbeAdapter(hang: true);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
  try { await DioNetworkClient(dio, deadline: const Duration(milliseconds: 20)).send(const NetworkRequest(path: '/hang', method: NetworkMethod.get)); throw StateError('positive deadline did not expire'); }
  on NetworkException catch(e) { check(e.code == 'RECEIVE_TIMEOUT', 'positive deadline code'); }
  await Future<void>.delayed(Duration.zero);
  check(adapter.cancelled, 'positive deadline cancellation');
  print('PASS positive deadline timeout and cancellation');
  dio.close(force: true);
}
