import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';

/// Dio adapter for [INetworkClient].
class DioNetworkClient implements INetworkClient {
  /// Creates a transport adapter over a configured Dio instance.
  ///
  /// [deadline], when given, bounds each [send] end to end: the whole
  /// interceptor chain, including retry backoff and a 401 refresh-and-replay,
  /// must finish within it. Dio's connect, send and receive timeouts each
  /// bound one phase of one attempt, so without this a request that keeps
  /// retrying has no upper bound at all. `ApiClient` passes
  /// `AppConfig.apiTimeout` (`API_TIMEOUT`) - koniz-dev/flutter-starter#280.
  DioNetworkClient(this._dio, {Duration? deadline}) : _deadline = deadline;

  final Dio _dio;
  final Duration? _deadline;

  @override
  Future<NetworkResponse<dynamic>> send(NetworkRequest request) async {
    final deadline = _deadline;
    final cancelToken = CancelToken();
    final pending = _send(request, cancelToken);
    if (deadline == null) return pending;
    return pending.timeout(
      deadline,
      onTimeout: () {
        // Stop the work as well as the wait; the abandoned future's own
        // cancellation error has no listener left to reach.
        cancelToken.cancel('API_TIMEOUT deadline exceeded');
        unawaited(pending.then<void>((_) {}, onError: (Object _) {}));
        // RECEIVE_TIMEOUT so the failure localizes as a timeout: the client
        // gave up waiting for a response.
        throw NetworkException(
          'Request deadline exceeded: no response within '
          '${deadline.inSeconds}s (API_TIMEOUT)',
          code: 'RECEIVE_TIMEOUT',
        );
      },
    );
  }

  Future<NetworkResponse<dynamic>> _send(
    NetworkRequest request,
    CancelToken cancelToken,
  ) async {
    try {
      final response = await _dio.request<dynamic>(
        request.path,
        data: request.body,
        queryParameters: request.queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: _toHttpMethod(request.method),
          headers: request.headers,
          sendTimeout: request.timeout,
          receiveTimeout: request.timeout,
        ),
      );

      return NetworkResponse<dynamic>(
        statusCode: response.statusCode ?? 0,
        data: response.data,
        headers: response.headers.map,
      );
    } on DioException catch (e) {
      final appError = e.error;
      if (appError is Exception) {
        throw appError;
      }
      throw NetworkError(
        message: e.message ?? 'Network request failed',
        code: e.type.name,
        statusCode: e.response?.statusCode,
        cause: e,
      );
    }
  }

  String _toHttpMethod(NetworkMethod method) {
    switch (method) {
      case NetworkMethod.get:
        return 'GET';
      case NetworkMethod.post:
        return 'POST';
      case NetworkMethod.put:
        return 'PUT';
      case NetworkMethod.patch:
        return 'PATCH';
      case NetworkMethod.delete:
        return 'DELETE';
    }
  }
}
