import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';

/// Dio adapter for [INetworkClient].
class DioNetworkClient implements INetworkClient {
  /// Creates a transport adapter over a configured Dio instance.
  DioNetworkClient(this._dio);

  final Dio _dio;

  @override
  Future<NetworkResponse<dynamic>> send(NetworkRequest request) async {
    try {
      final response = await _dio.request<dynamic>(
        request.path,
        data: request.body,
        queryParameters: request.queryParameters,
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
