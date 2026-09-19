import 'dart:typed_data';

import 'package:dio/dio.dart';

/// [HttpClientAdapter] that forwards every fetch to another client's adapter.
///
/// A secondary Dio (for example the one that replays a request after a token
/// refresh) must not build its own transport: a fresh `Dio` gets the default
/// system-trust-store adapter, which silently bypasses the certificate
/// pinning installed on the main client. Delegating keeps one transport, one
/// connection pool, and one pinning policy.
///
/// The target is resolved per fetch, so reassigning the owner's
/// `httpClientAdapter` (as tests do when installing a fake transport) is
/// picked up immediately.
///
/// [close] is intentionally a no-op: the owner of the delegated adapter closes
/// it.
class SharedTransportAdapter implements HttpClientAdapter {
  /// Creates an adapter delegating to the adapter `resolve` returns.
  SharedTransportAdapter(this._resolve);

  final HttpClientAdapter Function() _resolve;

  /// The adapter currently being delegated to.
  HttpClientAdapter get target => _resolve();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _resolve().fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    // The owning client closes the delegated transport.
  }
}
